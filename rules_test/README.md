# Firebase Rules unit tests

Requires **Java** + Firebase emulator tooling (`firebase-tools`).

## Firestore (WA-2+)

```bash
cd rules_test && npm install && cd ..
npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
  "npm --prefix rules_test test"
```

## Storage (WA-12 / C10)

Storage Rules call `firestore.get` / `exists`, so both emulators are required:

```bash
cd rules_test && npm install && cd ..
npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage \
  "npm --prefix rules_test run test:storage"
```

## All suites (Production Hardening 01)

Every suite uses the single project id in `project_id.mjs` (`demo-rafiq-rules`,
overridable with `RULES_TEST_PROJECT_ID`). The emulator `--project` must match,
and files run serially because they share one emulator project.

Run the Storage group in its own emulator session: the Storage emulator's
cross-service `firestore.get` reads go stale after many clear/seed cycles in
one session, which produces false denials unrelated to the rules.

```bash
npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
  "npm --prefix rules_test run test:all:firestore"
npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage \
  "npm --prefix rules_test run test:all:storage"
```

## Notes

- Do not claim Rules tests passed if Java / emulators are unavailable.
- Catch-all Storage access is **denied** (`allow read, write: if false`).
- Approved app prefixes: C10 paths + `posts/`, `content/`, `halaqa_activities/` (images only; audio denied while capability OFF).
- Unspecified paths remain fail-closed.
