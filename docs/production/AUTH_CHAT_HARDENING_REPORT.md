# Auth + Chat/Media Hardening Report

Wave: PRODUCTION HARDENING WAVE — FIX P0 REGRESSION + AUTH + CHAT/MEDIA
Date: 2026-10-06
Status: scope complete. Nothing committed, pushed, or deployed.

---

## 1. Region fix (Phase 0)

**Problem (post-merge audit B-1):** `adminReinstatePaymentAccess` and `adminGenerateInvoice` were declared without a region (default `us-central1`), while the Flutter client calls `FirebaseFunctions.instanceFor(region: 'europe-west1')`. Both Admin flows returned NOT_FOUND from the app.

**Fix:**
- `functions/src/admin/adminBilling.ts`: both callables now declare `{ region: "europe-west1" }`, the project convention. No other function region was changed.
- No client change was needed; `lib/core/di/di_module.dart` already targets `europe-west1`.
- Emulator config: `firebase.json` was checked; the emulator serves functions per declared region, and the tests call the client region URL.

**Protection against regression:**
- `functions/test/callable_region_contract.test.mjs` (unit, runs in `npm test`):
  - It reads the compiled deploy manifest (`__endpoint`, the metadata `firebase deploy` uses).
  - It collects every `httpsCallable('…')` name used under `lib/**`.
  - It fails if any of those names is missing, is not a callable trigger, or is deployed outside the client's region.
  - It automatically covers the new `sendChatMessage`.
- `functions/test/admin_billing_callable.emulator.test.mjs`:
  - It calls both Admin callables over HTTP at the client-region URL and covers generating an invoice and reinstating payment access.
  - It asserts nothing is served from `us-central1`.
  - It checks that non-admin callers and a **deactivated Admin** are denied (PERMISSION_DENIED).

**Report wording (B-2):** `P0_COMPLETION_REPORT.md` §2 now states that Supervisor overlap is **allowed** by D9, not a "blocked overlap".

---

## 2. Auth architecture and flows (Phase 1, D1)

**Architecture:** Clean Architecture, unchanged in shape. Components:
- datasource: `AuthRemoteDatasourceImpl`;
- repository: `AuthRepositoryImpl`;
- use cases: `LoginWithEmail`, `Logout`, `GetCurrentUser`, `WatchAuthSession`, `SendPasswordReset`;
- `AuthBloc` and `PasswordResetBloc`;
- GoRouter redirect: `AuthRedirect` in `router_app.dart`.

**Public self-registration was removed (D1).** The register page offered real public account creation (case A), so these were deleted:
- `register_page.dart`
- `register_with_email_usecase.dart`
- the register route and links
- `academy_admission_firestore.dart`, a client-side admission writer

Accounts are only provisioned by Admin on the server. The client never writes its own role, `isActive` or `paymentAccess`.

**Flow coverage:**

| Flow | Behaviour |
|---|---|
| Cold start / restore | Splash → `CheckAuthStatusEvent` → Firebase session restore → profile load → role home, or Login |
| Login success | Role-aware home through `AuthRedirect` |
| Invalid credentials / invalid email | Terminal `AuthError` with a clear Arabic message |
| Not provisioned (no `users/{uid}` profile) | Signed out, "not provisioned" message (`AuthErrorReason.notProvisioned`) |
| Disabled (`isActive == false` or Firebase-disabled) | Signed out, "disabled" message |
| Network failure | Retryable `AuthError` / `AuthStartupFailure` with a retry action |
| Too many requests | Specific message |
| Session revoked / expired while in the app | `SessionEndedEvent` → Login with an explanation |
| Logout success / failure | `AuthUnauthenticated`; on failure `AuthLogoutFailure` keeps the session and reports the error |
| Wrong role on another role's route | Redirected to the caller's own home |
| Forgot password | `PasswordResetBloc`: Idle → Submitting → EmailSent (double-submit ignored) → back to Login; invalid email is terminal, network failure is retryable; "edit address" goes back to the form |

The new password is set on Firebase's hosted reset page. That is the existing Firebase Auth contract; no OTP architecture was invented.

---

## 3. Auth security

**Fail-closed role resolution:** `activeRoleOf()` in `functions/src/authority/callerContext.ts` returns no role when `isActive != true`. It is used by:
- `assertAdmin`
- `materializeSession`
- `loadChatRelationships` / `loadUserRole`

**Rules:**
- Firestore `hasRole()` and Storage `activeRole()` both require `isActive == true`.
- A deactivated profile has no effective role and cannot reactivate itself. This is covered by a rules test.

**The client cannot:**
- choose or write its own role;
- create privileged users;
- write `paymentAccess`;
- bypass provisioning.

These are enforced by existing rules and covered by the rules suites.

**Residuals (not blockers):**
- Admin deactivation does not disable the Firebase Auth account; access is denied by the role and `isActive` checks instead.
- Conversation and message reads by a deactivated participant: fixed in Firestore rules (§16).

---

## 4. Auth UI coverage

The login, forgot-password and splash pages were rebuilt from small reusable widgets in `auth_widgets.dart`:
- `AuthHeaderBackdrop`
- `AuthBrandHeader`
- `AuthFieldLabel`
- `AuthMessageBanner` with error, info and success tones

UI guarantees:
- Every state has loading, error, retry (where applicable) and success.
- All text is Arabic RTL.
- There are no fake buttons, fake OTP timers, "coming soon" Auth actions, hardcoded accounts or mock authentication.
- There is only one login flow.

---

## 5. Chat architecture

**Kept from the locked architecture:**
- 1:1 conversations, and Halaqa group conversations `halaqa_group_{halaqaId}` whose membership is projected server-side by `syncHalaqaGroupOnWrite`.
- Parents are not in Student Halaqa chat.
- There is no academy-wide group.
- Admin is not a group member; Admin keeps moderation access only.
- Chat stays separate from Posts and Content Library.

**Changed (single SSOT, server-authoritative writes):**
- **Message creation moved to the server.** The new callable `sendChatMessage` (`functions/src/chat/chatMessageFunctions.ts`, region `europe-west1`) writes:
  - `senderId` and `sentAt` (server timestamp);
  - the conversation preview fields (`lastMessage`, `lastMessageAt`, `lastMessageSenderId`, `lastMessageId`, `lastMessageType`);
  - `unreadCounts.{other}` incremented by 1.

  The message create and the conversation update happen in one transaction.
- Firestore rules now deny client message `create` and `update`. The only client write left on a conversation is resetting **its own** unread counter to 0.
- The pure contract `chatMessageContract.ts` defines:
  - limits: text up to 4000 characters, voice up to 10 minutes;
  - the message ID pattern;
  - the per-type media policy;
  - file signatures;
  - preview strings.
- Messages are idempotent by client-generated `messageId` (20 alphanumeric characters):
  - A retry with the same ID returns `created:false`.
  - The same ID from another sender returns ALREADY_EXISTS.

**Flutter:**
- New or extended entities: `ChatMessageType`, `ChatMediaEntity`, and `MessageEntity.type/media/visibleMedia` (media is hidden when a message is deleted).
- `ChatMediaPolicy` is the client mirror of the server policy (the server stays authoritative).
- `ChatRoomBloc` gains:
  - an in-memory outbox with uploading / sending / sent / failed states;
  - retry and cancel;
  - pagination;
  - unread reset.
- `ChatMediaLoader` keeps an in-memory image LRU cache and temporary files for voice and documents; it is cleared on logout.

---

## 6. Message edit/delete

Both run through the existing callables in `chatAuthFunctions.ts`.

**Edit:**
- Allowed for the sender, on text messages only, within the 15-minute window.
- Text is normalized and limited to 4000 characters.
- The caller needs an active role.
- Media messages are rejected with "لا يمكن تعديل رسائل الوسائط".
- `updatedAt` is set, and the conversation preview is updated if the edited message is the latest.

**Soft delete:**
- Allowed for the sender, or for Admin as moderation.
- Sets `deleted:true` and removes the `media` field.
- If it was the latest message, the preview becomes "تم حذف هذه الرسالة".
- Deleting twice is rejected.
- The Storage object is kept and becomes Admin-readable only; the retention policy is D20, deferred.

**UI:** long-press opens a sheet with "نسخ النص", plus "تعديل" and "حذف" on the user's own recent text messages. Edit opens a dialog and delete asks for confirmation. Failures appear as action-error snackbars.

Residual: Admin moderation delete exists on the server, but the UI only offers delete on the user's own messages.

---

## 7. Image/file/voice media

| Type | Storage prefix | Max size | Allowed types |
|---|---|---|---|
| Image | `chat_media/{conv}/{msg}/image.{ext}` | < 10 MB | JPEG, PNG, WebP |
| Voice | `chat_voice/{conv}/{msg}/voice.m4a` | < 20 MB, ≤ 10 min | audio/mp4, m4a, aac, mpeg, ogg, webm, wav |
| File | `chat_attachments/{conv}/{msg}/file.{ext}` | < 10 MB | PDF, DOC, DOCX |

**Send pipeline:**
1. Client-side validation.
2. `putFile` with `customMetadata.uploaderId`, showing progress (`جارٍ الرفع N٪`) and allowing cancel.
3. When the upload completes, the client calls `sendChatMessage` with the storage path.
4. The server verifies:
   - the object exists;
   - the uploader matches the caller;
   - the size is within limits;
   - the MIME type is allowed;
   - the first bytes match the expected signature.
5. The server creates the message.

**Failure handling:**
- An upload failure leaves a failed item with "إعادة المحاولة"; retry deletes the partial object first, then re-uploads.
- A send failure after a successful upload is retried by re-sending only (idempotent, no re-upload).
- Cancelling, or leaving the room, cancels the task and deletes the orphan object, which the uploader may do while no message references it.

**Input and playback:**
- Voice is recorded with `record` (AAC-LC, 64 kbps). The mic permission is requested and denial is explained. Clips under 1 second are rejected ("التسجيل قصير جداً"), and recording auto-stops at 10 minutes.
- Image picking compresses at quality 80.
- Images open full-screen with zoom, voice plays through `just_audio`, and files open via `open_filex`.
- Android declares `RECORD_AUDIO`. iOS has Arabic `NSMicrophoneUsageDescription` and `NSPhotoLibraryUsageDescription` strings.

---

## 8. Firestore/Storage security

**Firestore (`firestore.rules`):**
- Messages: client create, update and delete are all `false`.
- Conversations: a participant may only update `unreadCounts.{self}` to 0. The preview, participants and other fields are server-only.
- Removed now-unused helpers: `isHalaqaGroupId`, `isHalaqaGroupDoc`, `groupMembershipFrozen`, `directMembershipFrozen`.
- A deactivated Admin is denied conversation reads.

**Storage (`storage.rules`):**
- **Read:** Admin; or a participant, when the message exists, is not deleted, and `media.storagePath` equals the requested path.
- **Upload:**
  - the caller is a participant;
  - the message ID matches the pattern;
  - no object exists yet (no overwrite);
  - `metadata.uploaderId == uid`;
  - no message document exists yet;
  - the folder's MIME allow-list and size limit are satisfied.
- **Delete:** only the uploader, and only while no message references the object.
- `canAccessConversationMedia` was replaced by message-scoped checks.

**Residuals:**
- Deactivated participant reads of conversations and messages: fixed (§16). Storage chat media reads are still not activity-gated (§16, related finding).
- There is no rate limiting.
- The voice `durationMs` is client-reported and used only for display.
- The number of cross-service document reads per Storage request needs staging verification (cost and limits).

---

## 9. Real-time behavior

- **Live updates:** messages stream with `orderBy(sentAt desc).limit(N)` and are shown in reverse.
  - The page size is 30.
  - "عرض الرسائل الأقدم" and scrolling to the top grow the window, but only when a full page came back (`hasMore`).
- **Outbox:** optimistic items stay until the stream confirms the same `messageId`, so messages are never shown twice.
- **Unread:**
  - The counter is reset when the room opens, and once per new incoming message while the room stays open.
  - The user's own messages never reset it.
  - Increments happen inside the send transaction, so concurrent senders are counted exactly (emulator-tested).
- **Errors:** stream errors keep the history visible and show a banner with retry. Losing access maps to "لم يعد لديك وصول إلى هذه المحادثة".
- **Concurrency:**
  - Parallel distinct sends are all counted.
  - Parallel duplicate sends collapse to one message and one unread increment (emulator-tested).

---

## 10. Tests

All runs were on the `demo-rafiq-rules` emulator project.

| Suite | Result |
|---|---|
| Flutter full suite (`flutter test`) | **814 passed, 2 skipped**, 0 failed (baseline 729 / 2) |
| Chat + security Flutter subset | 82 / 82 (later 123 / 123 for auth, router and chat after formatting) |
| Functions unit (`npm test`, includes region contract and chat contract) | **259 / 259** |
| P0 callable emulator | **24 / 24** |
| PH-02 callable emulator | **50 / 50** |
| Admin billing callable emulator | **5 / 5** |
| Chat callable emulator (new) | **14 / 14** |
| Firestore rules (firestore, ph01, ph02, p0) | **185 / 185** |
| Storage rules (storage, ph01, p0) | **40 / 40** |

**New or rewritten tests in this wave:**
- `callable_region_contract.test.mjs`
- `admin_billing_callable.emulator.test.mjs`
- `chat_message_contract.test.mjs`
- `chat_message_callable.emulator.test.mjs`
- Rules tests:
  - unread reset only;
  - client message create denied;
  - deactivated Admin denied;
  - D1 deactivated profile;
  - 12 Storage chat tests.
- Flutter Auth: bloc, datasource, pages, router redirect.
- Flutter Chat:
  - `chat_room_bloc_test` (13 tests);
  - `chat_room_page_test` (8 widget tests);
  - `chat_media_policy_test`;
  - `chat_repository_watch_test`;
  - `send_and_mark_as_read_usecase_test`;
  - a `chatAttachment` path assertion in `wa12`.

**Notes on runs:**
- In one combined emulator session, a PH-02 concurrency test failed once with "Transaction is invalid or closed". The cause was emulator contention, and the test passed 50/50 on rerun. It is a PH-02 file and was not modified.
- In a combined session, the chat concurrency test failed because the PH-02 and P0 suites seed halaqa `h1`, and their late `syncHalaqaGroupOnWrite` triggers rewrote `halaqa_group_h1` mid-test. The chat suite now uses its own halaqa ID (`chat_h1`). Re-run after PH-02 in the same session, it passed 14/14.
- Drive C: ran out of space during verification. This corrupted the compiled `functions/lib` output, which was rebuilt; all source files were checked and are intact. Keep ≥ 5 GB free on C: for emulator runs.

---

## 11. Existing baseline vs new issues

| Metric | Baseline | Now |
|---|---|---|
| `flutter analyze` issues | 120 | **114** |
| Errors | 0 | **0** |
| Warnings | 7 | **7** (same pre-existing set: unused imports in audio_library and older tests, one unused parameter) |

- No new warnings or errors. The new test fakes for Firestore sealed types use targeted `// ignore: subtype_of_sealed_class`.
- Formatting: all Dart files created in this wave are `dart format`-clean. Modified pre-existing files were not reformatted wholesale, because the repo is not format-enforced (about 85 unrelated files differ from `dart format`) and that would add unrelated diff noise.
- UTF-8 without BOM was verified on all changed and new files.
- Known minor issues from the post-merge audit were left as they were, per scope:
  - non-transactional reinstatement;
  - the legacy-to-`lessonHomework` change;
  - post-author editable fields;
  - Admin Bloc fakes;
  - push cold-start.

---

## 12. Deferred business decisions

- **Supervisor payment scope:** whether a Supervisor may review payments for students whose main Halaqa belongs to another Supervisor. Not decided in this wave.
- **D20 retention of deleted chat media:** objects are kept and Admin-readable only; a retention or purge policy is TBD.
- **Admin moderation-delete UI:** exists on the server, but there is no UI entry point; this is a product decision.
- **Rate limiting / abuse controls for chat sends:** needs a product and infrastructure decision.
- **Disabling the Firebase Auth account on Admin deactivation:** today access is denied through the `isActive` and role checks only.

---

## 13. Remaining device/staging verification

- Real-device checks:
  - mic permission prompts, including permanently-denied handling;
  - background or interrupted recording;
  - AAC playback via `just_audio` on Android and iOS.
- iOS:
  - HEIC images through `file_picker` compression must arrive as JPEG; the server rejects HEIC by signature;
  - photo library permission text.
- `open_filex` behaviour for PDF and DOCX on both platforms.
- Large uploads on poor networks: progress, cancel and retry.
- Staging:
  - Storage rules cross-service `firestore.get`/`exists` read counts and latency;
  - `sendChatMessage` cold-start latency in `europe-west1`.
- Push cold-start (pre-existing audit item).
- Password reset completion on the Firebase-hosted page, using the production email template.
- Callables are gated by `assertBackendAllowed` in production, so the enablement must be confirmed at deploy time.

---

## 14. Files changed (this wave)

**Functions**
- `functions/src/admin/adminBilling.ts` (region)
- `functions/src/admin/assertAdmin.ts`
- `functions/src/sessions/materializeSession.ts`
- `functions/src/authority/callerContext.ts` (`activeRoleOf`)
- `functions/src/chat/loadChatRelationships.ts`
- `functions/src/chat/chatMessageContract.ts` (new)
- `functions/src/chat/chatMessageFunctions.ts` (new)
- `functions/src/chat/chatAuthFunctions.ts`
- `functions/src/index.ts`
- `functions/package.json`
- `functions/test/callable_region_contract.test.mjs` (new)
- `functions/test/admin_billing_callable.emulator.test.mjs` (new)
- `functions/test/chat_message_contract.test.mjs` (new)
- `functions/test/chat_message_callable.emulator.test.mjs` (new)

**Rules**
- `firestore.rules`
- `storage.rules`
- `rules_test/firestore.rules.test.mjs`
- `rules_test/storage.rules.test.mjs`
- `rules_test/ph01_authorization.rules.test.mjs`

**Platform**
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

**Flutter: Auth**
- `lib/core/error/auth_error_reason.dart` (new)
- `lib/core/router/router_app.dart`
- `lib/features/auth/**`:
  - datasource, repository, Bloc, events and states;
  - login and splash pages;
  - new: `forgot_password_page.dart`, `password_reset_bloc.dart`, `auth_widgets.dart`, `auth_error_messages.dart`, `send_password_reset_usecase.dart`, `watch_auth_session_usecase.dart`;
  - deleted: `register_page.dart`, `register_with_email_usecase.dart`.
- `lib/shared/data/academy_admission_firestore.dart` (deleted)

**Flutter: Chat**
- `lib/features/chat/data/datasources/chat_remote_datasource.dart`
- `lib/features/chat/data/models/chat_models.dart`
- `lib/features/chat/data/repositories/chat_repository_impl.dart`
- `lib/features/chat/domain/entities/chat_entities.dart`
- `lib/features/chat/domain/repositories/chat_repository.dart`
- `lib/features/chat/domain/usecases/chat_usecases.dart`
- `lib/features/chat/domain/policies/chat_media_policy.dart` (new)
- `lib/features/chat/presentation/bloc/chat_room_bloc.dart`, `chat_room_event.dart`, `chat_room_state.dart`
- `lib/features/chat/presentation/pages/chat_room.dart`
- `lib/features/chat/presentation/media/chat_media_loader.dart` (new)
- `lib/features/chat/presentation/media/chat_voice_recorder.dart` (new)
- `lib/features/chat/presentation/widgets/chat_composer.dart` (new)
- `lib/features/chat/presentation/widgets/chat_message_bubble.dart` (new)
- `lib/features/chat/presentation/widgets/chat_media_views.dart` (new)
- `lib/shared/domain/storage_paths_contract.dart`
- `lib/core/session/clear_session_projections.dart`
- `lib/core/di/injection_container.config.dart` (regenerated)

**Flutter tests**
- `test/features/auth/*` (new)
- `test/core/router/auth_redirect_test.dart` (new)
- `test/features/chat/chat_room_bloc_test.dart`, `chat_room_page_test.dart` (new), `chat_media_policy_test.dart` (new), `chat_repository_watch_test.dart`, `send_and_mark_as_read_usecase_test.dart`
- `test/security/wa12_storage_paths_contract_test.dart`

**Docs**
- `docs/production/P0_COMPLETION_REPORT.md` (§2 wording)
- `docs/production/AUTH_CHAT_HARDENING_REPORT.md` (this file)

Many other files in the working tree belong to earlier uncommitted waves and were not touched here.

---

## 15. Confirmation

- No `git commit`, `git push` or `firebase deploy` was run.
- Production Firebase configuration was not changed; the only region change is the two Admin billing callables, matching the existing `europe-west1` convention.
- PH-02 was not reopened, and Mushaf was not modified.
- No new points or game system, pricing, plans, or content was invented.
- Do not commit or stage these untracked files: `unit_out.txt`, `.cursor/mcp.json`, `rules_test/node_modules/`. All temporary logs from this wave have been deleted.

---

## 16. Pre-staging fix: deactivated chat participant read gap

**Gap:** a deactivated non-Admin user still holding a valid Firebase Auth token could read conversations and messages they were already a participant in. The participant checks in `firestore.rules` only required `signedIn()` and membership in `participantIds`; only the Admin path was activity-gated, through `hasRole`.

**Rules fix (`firestore.rules`):**
- New shared helper `hasActiveProfile()`: signed in, `users/{uid}` exists, and `isActive != false`. `hasRole()` now reuses it, so there is still a single activity contract.
- Both chat participant checks now require `hasActiveProfile()`:
  - `isConversationParticipant()` covers conversation reads and the caller's own unread reset;
  - `isMsgConversationParticipant()` covers message reads.
- Admin monitoring is unchanged (`isAdmin()`, which already fails for a deactivated Admin). No access was broadened.
- Cost: one `users/{uid}` lookup inside rule evaluation, served from the rules cache when the same evaluation reads it more than once. There is no client-side profile fetch and no N+1 query.
- Activity contract: a missing `isActive` counts as a legacy active profile, matching `hasRole`, Storage `activeRole()` and the server's `activeRoleOf()`. Deactivation always writes `isActive: false`, which this rule denies.

**Pre-existing bug found and fixed in the same function:** the app's conversation list query (`participantIds array-contains uid` ordered by `lastMessageAt`, used by `ChatRemoteDatasource.watchConversations`) was **denied by the rules even before this change**. The `resource.data.participantIds is list` guard cannot be proven for a query. That guard was removed from the conversation-level check only:
- `uid() in resource.data.participantIds` is safe for the List shape that is currently enforced: only server code writes `participantIds`, it always writes a List, and clients cannot write this field. On a List, `in` is a membership test, and a string value is denied (tested). A Map would behave differently: `in` checks the Map's keys, so a malformed, server-written Map such as `{uid: true}` would pass the conversation-level check. The message-level check keeps its `is list` guard;
- listing other users' conversations, unfiltered listing, and malformed documents all stay denied (tested).

**New emulator tests** (`rules_test/firestore.rules.test.mjs`, "Chat read gate", 9 tests). They cover:
- An active participant reads the conversation and messages, and lists its messages and own conversations (the app's exact query).
- A deactivated participant is denied the conversation, messages, both lists, and Halaqa group messages.
- A client signed in while active, carrying `isActive: true` and role claims in its token, is denied after deactivation for reads and unread reset.
- A re-activated participant can read again.
- A deactivated Admin is denied monitoring reads; an active Admin keeps monitoring, including listing.
- Non-participants (another student, Parent, Supervisor), a missing profile and an unauthenticated caller are denied. Listing another user's conversations, unfiltered listing, and a malformed `participantIds` are denied.
- Parent 1:1, Teacher, Supervisor and Halaqa-group access is unchanged, and a Parent is still not in the group.
- Unread reset works for active users and is denied after deactivation; resetting another member's counter stays denied.
- A legacy profile without `isActive` keeps access.

**Final verification after the fix:**

| Suite | Result |
|---|---|
| Firestore rules (firestore, ph01, ph02, p0) | **194 / 194** (185 + 9 new) |
| Storage rules | **40 / 40** (Storage rules not modified) |
| Functions unit | **259 / 259** |
| P0 / PH-02 / billing / chat callable emulator | **24 / 24, 50 / 50, 5 / 5, 14 / 14** |
| Flutter full suite | **814 passed, 2 skipped** |
| `flutter analyze` | **114 issues, 0 errors, 7 warnings** (unchanged) |

Only `firestore.rules`, `rules_test/firestore.rules.test.mjs` and these docs changed for this fix.

**Security review:** APPROVED. See `PRE_STAGING_SECURITY_CHECK.md` for the two low-severity observations and three non-blocking test gaps recorded by the review.

**Related finding, DEFERRED (Storage changes are currently frozen):** Storage chat media reads use their own participant check (`isConversationParticipant(conversationId)` in `storage.rules`), which is not activity-gated either. A deactivated participant who already knows an object path could still download that one media file. They can no longer read message documents to discover new paths, and cannot upload or send. The fix location is `storage.rules` (require `activeRole() != ''` in that helper). It has not been applied.

---

## Classification

### VERIFIED
- Region fix for `adminReinstatePaymentAccess` and `adminGenerateInvoice`, plus the manifest-based region contract test and the emulator flows at the client region.
- D1: no public self-registration path. Admin-only provisioning, and the client cannot write role, `isActive` or `paymentAccess`.
- Auth lifecycle: restore, login outcomes, not-provisioned, disabled, network retry, session ended, logout, role redirect, password reset request.
- Fail-closed role resolution (`activeRoleOf`, `hasRole`, `activeRole`) for Admin, callables and rules.
- Server-authoritative chat send (text, image, voice, file):
  - identity, timestamp, preview and unread are written by the server;
  - idempotent, concurrency-safe.
- Edit (own text, 15 minutes) and soft delete (sender or Admin), with media stripped and the preview updated.
- Storage rules: message-scoped read, no overwrite, uploader-bound upload, orphan delete, per-type MIME and size limits.
- Flutter outbox: progress, cancel, retry without duplicate upload, dedupe; pagination; unread reset.
- All suites listed in §10 pass, and `flutter analyze` has no new errors or warnings.

- Deactivated chat participant read gap closed in Firestore rules (§16), and the app's conversation-list query is now allowed by the rules (§16). **VERIFIED / APPROVED** by security review.

### NEEDS FIX BEFORE STAGING
- None.

### DEFERRED / DEVICE VERIFICATION
- **Deferred security item:** chat media read access for deactivated accounts. Status: DEFERRED. Reason: Storage changes are currently frozen. Fix location: `storage.rules` (§16).
- Deferred decisions: Supervisor payment scope; D20 media retention; Admin moderation-delete UI; chat rate limiting; disabling the Firebase Auth account on deactivation.
- Device: mic permission and recording, AAC playback, iOS HEIC→JPEG, `open_filex`, large uploads on poor networks, push cold-start.
- Staging: Storage cross-service read counts and latency; `sendChatMessage` cold start; production `assertBackendAllowed` enablement; the hosted password-reset page and template.
