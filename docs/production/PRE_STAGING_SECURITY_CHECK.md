# Pre-Staging Security Check

Date: 2026-10-06
Scope: state after the Auth + Chat/Media Hardening wave and the deactivated-participant read fix.
Nothing has been committed, pushed or deployed. Staging has not been started.

## Verdict

**APPROVED — READY FOR STAGING.** Everything that can be verified without devices is verified. The Firestore chat deactivation hardening passed security review (APPROVE). The only known deferred security item is listed below; device checks, follow-up tests and business decisions are listed separately and do not block a staging deploy.

## Verified technical items

| Item | Status | Evidence |
|---|---|---|
| Admin billing callables in the client region (`europe-west1`) | Verified | Region contract unit test; billing emulator 5/5 |
| Every client callable deployed in the client region | Verified | `callable_region_contract.test.mjs` |
| D1: no public self-registration; Admin-only provisioning | Verified | Register path removed; rules deny client role / `isActive` / `paymentAccess` writes |
| Deactivated profile holds no role (rules + callables) | Verified | `hasActiveProfile`/`hasRole`, Storage `activeRole`, `activeRoleOf`; D1 rules test; deactivated-Admin billing test |
| Firestore chat deactivation hardening: deactivated participant cannot read conversations / messages | **VERIFIED / APPROVED** | 9 "Chat read gate" rules tests; security review APPROVE |
| An old valid token does not bypass deactivation | Verified | Same signed-in client denied after deactivation |
| Re-activation restores access | Verified | Rules test |
| App conversation-list query allowed for own conversations only | Verified | Rules tests (pre-existing denial fixed) |
| Parent / Teacher / Supervisor / Halaqa group access unchanged | Verified | Rules tests; Parent not in group |
| Admin monitoring unchanged; deactivated Admin denied | Verified | Rules tests |
| Message create / edit / delete server-only, with relationship checks | Verified | Chat emulator 14/14; rules deny client message writes |
| Unread: server increments; client may only reset its own counter to 0 | Verified | Rules + emulator tests |
| Chat media: uploader-bound, no overwrite, MIME / size / signature checked | Verified | Storage rules 40/40; chat emulator media tests |
| PH-02 closed / P0 closed | Verified | PH-02 emulator 50/50; P0 emulator 24/24 |

**Test totals:**
- Firestore rules: 194/194
- Storage rules: 40/40
- Functions unit: 259/259
- Callable emulator suites: 93/93
- Flutter: 814 passed, 2 skipped
- `flutter analyze`: 0 errors, 7 warnings, all pre-existing (baseline unchanged)

## Deferred security item (the only one currently known)

- **Chat media read access for deactivated accounts**
  - Status: `DEFERRED`
  - Reason: Storage changes are currently frozen
  - Fix location: `storage.rules` (`isConversationParticipant(conversationId)` is not activity-gated; a deactivated user who already knows an object path can still download that file)
  - Not applied; `storage.rules` is unchanged.

## Security review observations (low severity, non-blocking)

- **`participantIds` Map semantics:** the conversation-level check is `uid() in resource.data.participantIds`. If malformed, server-written data ever stored this field as a Map, `in` would check the Map's keys and could broaden conversation-level membership. Current server writes use a List, and clients cannot write this field.
- **Non-boolean `isActive`:** values such as `"false"` or `0` pass `!= false`. Actual deactivation writes boolean `false`, and this matches existing Auth, Storage and Functions behaviour.

## Follow-up test hardening (non-blocking, not staging blockers)

- [ ] A participant with no profile document is denied conversation and message reads.
- [ ] A malformed `participantIds` Map is denied.
- [ ] A legacy profile without `isActive` is tested for conversation read and the conversation-list query, not only message read.

## Real-device verification still required

- [ ] Microphone permission (first prompt, denied, permanently denied) and recording on Android and iOS
- [ ] Voice playback (`just_audio`, AAC/m4a) on both platforms
- [ ] iOS HEIC photos arrive as JPEG after picker compression (the server rejects HEIC)
- [ ] Opening PDF / DOC / DOCX via `open_filex`
- [ ] Large uploads on poor networks: progress, cancel, retry
- [ ] Push notification cold start
- [ ] Deactivated user is signed out on the device and cannot read chat after relaunch

## Staging verification (after deploy, not before)

- [ ] `sendChatMessage` cold-start latency in `europe-west1`
- [ ] Storage rules cross-service read counts and latency for chat media
- [ ] Callables enabled in production (`assertBackendAllowed`)
- [ ] Firebase-hosted password reset page and production email template
- [ ] Composite index for conversations (`participantIds` array-contains + `lastMessageAt` desc), defined in `firestore.indexes.json`, is deployed and built in the staging project

## Deferred business decisions (not blocking staging)

- [ ] Supervisor payment scope: reviewing students whose main Halaqa belongs to another Supervisor
- [ ] D20 retention / purge of deleted chat media (currently kept, Admin-readable only)
- [ ] Admin moderation-delete UI (server supports it; no UI entry point)
- [ ] Chat rate limiting / abuse controls
- [ ] Whether Admin deactivation should also disable the Firebase Auth account
