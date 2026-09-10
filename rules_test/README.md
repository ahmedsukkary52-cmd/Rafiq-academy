# Firestore Rules unit tests (WA-2)

Requires Java + Firebase emulator tooling.

```bash
cd rules_test
npm install
cd ..
npx firebase emulators:exec --project demo-rafiq-wa2 --only firestore "npm --prefix rules_test test"
```

These tests assert negative authorization for role escalation, phone privacy,
childrenIds, roster, payments, paymentAccess, academySettings, and wallets.
