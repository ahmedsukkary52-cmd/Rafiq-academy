# BASMA Agent Progress

Branch: `unify/basma-v1` @ `bb0a905` (preserved dirty tree)

## Session — E2E / UX trial (emulator)

### Runtime stack
- Firebase emulators: `demo-rafiq-rules` (auth/firestore/functions/storage) via `npm run serve`
- Seed: `npm run seed:emulator` + E2E relationship/pricing writes
- Android: Pixel_9_Pro `emulator-5554`
- **Required:** `adb reverse` for 9099/8080/5001/9199 (app uses `127.0.0.1` + `automaticHostMapping:false`)

### Critical fixes this session
1. **Stuck native splash** on plain `dev`: Firebase Messaging NPE when registrars removed → `android/app/src/dev/AndroidManifest.xml` keeps registrars (inert in emulator Dart)
2. **Onboarding** copy → academy BASMA (not Quran mushaf push); next CTA uses `arrow_back` for RTL
3. **Payment E2E (callables):** pricingRules → `adminGenerateInvoice` → Storage proof → `submitPaymentProof` → `reviewPaymentProof` approve → `paid`
4. **Messaging:** `startDirectChat` teacher→parent PASS
5. **Device:** Teacher login → home (`عبدالله الحربي`, tabs الرئيسية/الطلاب/الجوائز/الرسائل/حسابي) VERIFIED on emulator

### APK
- `build\app\outputs\flutter-apk\app-dev-debug.apk` ~173 MB
- Flavor: `dev` debug + `USE_FIREBASE_EMULATOR=true`
- Package: `com.example.rafiq_academy`
- Firebase target: emulator `demo-rafiq-rules` only (not academy-connected)

### Demo accounts (emulator; password temporarily `SeedDemo123` for adb)
- teacher@rafiq.demo, parent@rafiq.demo, student01@rafiq.demo, supervisor1@rafiq.demo, admin@rafiq.demo

### Still blocked for academy trial
- Owner Firebase project choice / Blaze / production signing
- Admin pricing UI (backend works; presentation incomplete)
- Assistant Teacher: no seeded account; role exists in app
- Full device UI for Parent/Admin/Supervisor/Student this session (Teacher device + callable E2E for payment/messaging)
