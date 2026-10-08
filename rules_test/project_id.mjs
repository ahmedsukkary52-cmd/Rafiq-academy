/**
 * Single emulator project id shared by every rules suite.
 *
 * Storage Rules call firestore.get/exists, which only resolve documents seeded
 * under the same project the emulators run with. Always pass
 * `--project demo-rafiq-rules` to `firebase emulators:exec` (see README).
 */
export const PROJECT_ID =
  process.env.RULES_TEST_PROJECT_ID ?? 'demo-rafiq-rules';
