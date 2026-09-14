# Firebase Rules unit tests

Requires **Java** + Firebase emulator tooling (`firebase-tools`).

## Firestore (WA-2+)

```bash
cd rules_test && npm install && cd ..
npx firebase emulators:exec --project demo-rafiq-wa2 --only firestore \
  "npm --prefix rules_test test"
```

## Storage (WA-12 / C10)

Storage Rules call `firestore.get` / `exists`, so both emulators are required:

```bash
cd rules_test && npm install && cd ..
npx firebase emulators:exec --project demo-rafiq-wa12 --only firestore,storage \
  "npm --prefix rules_test run test:storage"
```

## Notes

- Do not claim Rules tests passed if Java / emulators are unavailable.
- Catch-all Storage access is **denied** (`allow read, write: if false`).
- Approved app prefixes: C10 paths + `posts/`, `content/`, `halaqa_activities/` (images only; audio denied while capability OFF).
- Unspecified paths remain fail-closed.
