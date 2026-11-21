# Release platform setup — Android, iOS, Codemagic

Status: 2026-10-21. Local preparation only: nothing is signed with a real key,
built in CI, registered in a store or deployed.

Release gates cited here and in `codemagic.yaml`. These B numbers are release
gates; they are unrelated to the PH-02 decision codes in
`PH02_SUPERVISOR_AUTHORITY_REVIEW.md`, which reuse some of the same labels.

| Gate | Open until |
|---|---|
| B1 | The prod Firebase project exists. `rafiq-academy-staging` and `rafiq-academy-prod` are aliases only. |
| B2 | Prod app configuration exists: `android/app/src/prod/google-services.json` and prod `FirebaseOptions` (§1). |
| B7 | Blaze billing is enabled on the target project (`FIREBASE_BILLING_CHECKLIST.md`). |
| B8 | The Play upload keystore exists and is configured for prod release signing (§2). |
| B9 | `ios-unsigned-check` has passed on Codemagic (§3.1); signed iOS builds also need the Apple account items in §3. |
| B10 | A build carrying the minimum-version gate replaces every older build before the Firestore rules step (`PH02_DEPLOYMENT_ORDER.md` §4). |

## 1. Environments

| Flavor | Firebase project | Android applicationId | Android label | iOS |
|---|---|---|---|---|
| dev | `rafiq-academy` (existing; seed and test data only) | `com.example.rafiq_academy` | `بصمة (تطوير)` | `com.example.rafiqAcademy`; flavor files ready, not yet built (§3.1) |
| staging | `rafiq-academy-staging` (alias only; project not created) | `com.basmaacademy.app.staging` | `بصمة (تجريبي)` | not configured (optional, §3.1) |
| prod | separate new project (alias `rafiq-academy-prod`; not created) | `com.basmaacademy.app` | `بصمة` | `com.basmaacademy.app` (provisional); flavor files ready, not yet built (§3.1) |

Enforced in code, unchanged by this pass:
- `lib/core/firebase/app_flavor.dart`: dev must use `rafiq-academy`; staging and prod throw until configured, so no build can fall back to the dev project.
- `android/app/google-services.json` is the dev project only (`test/core/firebase/flavor_config_contract_test.dart`). Staging and prod configs go in `android/app/src/<flavor>/google-services.json`; until then Gradle fails with "No matching client found".
- `pubspec.yaml` `default-flavor: dev`.

To add prod later (owner creates the project first):
1. Register Android `com.basmaacademy.app` and the iOS bundle ID (§3) in the prod project.
2. Add `android/app/src/prod/google-services.json` and prod iOS options.
3. Add prod `FirebaseOptions` and return them from `firebaseOptionsFor(AppFlavor.prod)`, keeping the dev project check.
4. Update the flavor tests.

## 2. Android signing

Implemented locally in `android/app/build.gradle.kts`:
- **dev**, **staging**, and **trial**: debug key (local / non-store only; never uploaded to a store).
- **prod**: the Play **upload** key, from `android/key.properties` or, when that file is absent, from Codemagic's `CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD` (injected when `android_signing: [basma_upload_key]` is set).
- Without a complete upload key, any prod **release** artifact task (`assemble`, `bundle`, `package` or `install` + `ProdRelease`) stops the build with a message. Prod release cannot be debug-signed or left unsigned. Other flavors are unaffected.
- Ignore rules: `android/.gitignore` and the repo root `.gitignore` both ignore `key.properties` / `*.jks` / `*.keystore`.
- **Upload key vs Play App Signing key:** with Play App Signing, Google holds the app signing key that users' devices trust; the team keeps the **upload** keystore used only to sign AABs uploaded to Play. Losing the upload key is recoverable via Play support; losing an enrolled app signing key (if you managed it yourself without Play App Signing) is catastrophic. Prefer Play App Signing at first upload.
- Full readiness audit: `docs/engineering-audit/BASMA_RB17_ANDROID_SIGNING_AUDIT.md`.

Owner steps (no secret goes into Git or chat — never paste passwords or private keys into issues/chat):
1. Confirm the prod `applicationId` (provisionally `com.basmaacademy.app`) **before** the first Play Console upload.
2. Create the upload keystore on a trusted machine, for example
   `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`.
3. Store the `.jks` **outside** the repo; record store password, key alias, and key password in a password manager; keep an offline encrypted backup.
4. Verify fingerprints locally (do not commit the output files if they embed paths you care about):
   `keytool -list -v -keystore <path-to-upload-keystore.jks>`.
5. Local signing: create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. `storeFile` is relative to `android/app` or absolute. File stays git-ignored.
6. CI signing: upload the keystore in Codemagic (Team settings → Code signing identities → Android keystores) with the reference name **`basma_upload_key`** (must match `codemagic.yaml`).
7. Enroll the app in Play App Signing at first upload (Google holds the app signing key; the team keeps the upload key). Register the upload (and later Play) SHA-1/SHA-256 on the prod Firebase Android app.

Versioning: `pubspec.yaml` `version: 1.0.0+2` (J.10; earlier builds were `+1`) feeds `versionName` / `versionCode`. `kAppBuildNumber` must equal the `+N` (test-enforced) because the minimum-version gate uses it. Bump both in the repo for every store build; do not override with `--build-number`.

## 3. iOS

Committed project state (unchanged by this pass):
- Bundle ID `com.example.rafiqAcademy` (Runner); `RunnerTests` `com.example.rafiqAcademy.RunnerTests`.
- Automatic signing, no `DEVELOPMENT_TEAM`, deployment target 13.0.
- `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone and iPad).
- `lib/firebase_options.dart` has iOS options for `rafiq-academy` with bundle `com.example.rafiqAcademy`. Dart options are used, so no `GoogleService-Info.plist` is needed.
- Push (Phase 2, 2026-10-28): `ios/Runner/Runner.entitlements` holds `aps-environment` `development` (Xcode switches it to `production` when an App Store build is exported); each `Flavor-<flavor>.xcconfig` sets `CODE_SIGN_ENTITLEMENTS`, and `Info.plist` has `UIBackgroundModes` `remote-notification`. The FCM token registrar keeps watching token refreshes when the first token read fails, which is how iOS delivers the token once APNs has issued its own. Checked by `ios_flavor_contract_test.dart` and `wa13_fcm_token_contract_test.dart`; not yet built on macOS.
- `Runner.xcodeproj` still has only `Debug`/`Release`/`Profile` and the `Runner` scheme.

Why flavors are required: the app reads the flavor through `appFlavor` and throws when it is missing or unknown (`currentAppFlavor`). With `default-flavor: dev`, every `flutter build ios` needs a `dev` scheme and `<Mode>-dev` configurations.

### 3.1 Flavor setup (2026-10-21, local; not yet built on macOS)

The Xcode project file is never edited by hand. `ios/scripts/configure_flavors.rb` uses the `xcodeproj` library (the one CocoaPods uses) to add the flavors. Codemagic runs it on macOS before each iOS build.

| File | Purpose |
|---|---|
| `ios/scripts/configure_flavors.rb` | Adds `Debug-`/`Release-`/`Profile-` + `dev`/`prod` to the project and to both targets, copying the matching original configuration. Points Runner's flavored configurations at the wrappers below and drops their target-level bundle ID. Writes `dev.xcscheme` / `prod.xcscheme` from `Runner.xcscheme`. Idempotent. |
| `ios/Flutter/Flavor-dev.xcconfig` | `PRODUCT_BUNDLE_IDENTIFIER = com.example.rafiqAcademy` (registered in `rafiq-academy`), `APP_DISPLAY_NAME = بصمة (تطوير)` |
| `ios/Flutter/Flavor-prod.xcconfig` | `PRODUCT_BUNDLE_IDENTIFIER = com.basmaacademy.app` (**provisional**, copied from the Android prod ID; confirm before the App Store record), `APP_DISPLAY_NAME = بصمة` |
| `ios/Flutter/<Mode>-<flavor>.xcconfig` (6) | Include `Pods-Runner.<mode>-<flavor>.xcconfig`, `Generated.xcconfig` and the flavor file |
| `ios/Flutter/Debug.xcconfig`, `Release.xcconfig` | `APP_DISPLAY_NAME = بصمة` for unflavored builds |
| `ios/Runner/Info.plist` | `CFBundleDisplayName = $(APP_DISPLAY_NAME)`; `UIBackgroundModes` `remote-notification` |
| `ios/Runner/Runner.entitlements` | `aps-environment`, referenced by `CODE_SIGN_ENTITLEMENTS` in both flavor files (no target-level value in `project.pbxproj`) |
| `ios/Podfile` | Flutter's template, `platform :ios, '13.0'`, all nine configurations mapped. 13.0 is the highest minimum among the iOS plugins and Firebase iOS SDK 11.15.0 (`firebase_core` 3.15.2). |

Staging is not configured on iOS. Nothing requires it: the client code supports a staging flavor, but no staging project exists. To add it later, add `staging` to `FLAVORS` in the script, add the `Flavor-staging.xcconfig` and its three wrappers, and map them in the `Podfile`.

Local evidence on Windows (Ruby 4.0.7, xcodeproj 1.25.1, on a copy of `ios/` outside the repository):
- The script ran twice: the second run changed no file.
- All three configuration lists gained the six flavored configurations.
- Every flavored Runner configuration uses its own wrapper and has no target-level bundle ID; its other settings equal the source configuration.
- The original configurations are unchanged.
- The `dev`/`prod` schemes use their flavored configurations in all five actions.
- The `project.pbxproj` diff is 572 lines added, 0 removed.
- `test/core/release/ios_flavor_contract_test.dart` checks the files above.

**Not verified:** no `pod install`, Xcode build or simulator run has happened. `Podfile.lock` does not exist yet. iOS must not be called buildable until `ios-unsigned-check` passes on Codemagic.

After the first green Codemagic build:
1. Download `ios-flavor-project.zip`.
2. Review it and commit the generated `Runner.xcodeproj` changes, schemes and `Podfile.lock`. Committing the script's output in the repository is optional; the script stays idempotent either way.

Needs the Apple Developer account:
- Team ID, signing certificates and profiles, App Store Connect record.
- Push Notifications capability enabled on each App ID, so the provisioning profiles carry `aps-environment` (the entitlement and background mode are already in the repository), and an APNs auth key uploaded to each Firebase project. Until then a signed build fails on the entitlement, and iOS devices receive no pushes.
- TestFlight.

Decision needed: the prod iOS bundle ID. `Flavor-prod.xcconfig` provisionally uses the Android prod ID `com.basmaacademy.app`. That is enough for unsigned builds, but it becomes permanent once the App Store record exists, so confirm it first. Also decide whether iPad is supported. If not, set the device family to iPhone only before the first submission. Otherwise, iPad screenshots are required.

## 4. Codemagic

`codemagic.yaml` (manual workflows only, no secrets, nothing deployed):

| Workflow | What it does | Ready? |
|---|---|---|
| `android-dev-check` | `flutter analyze` (errors fail), `flutter test`, dev debug APK | Ready once the repo is connected to Codemagic; not yet run there |
| `android-prod-release` | tests, prod signed AAB using keystore reference `basma_upload_key` | Blocked: prod Firebase config (B1/B2), upload key (B8) |
| `ios-unsigned-check` | adds the flavors (§3.1), unsigned dev and prod release builds, archives each unsigned app before the next build replaces it, exports the generated Xcode project and `Podfile.lock` | Needs no Apple account. Not yet run (no Codemagic connection). The prod build compiles, but the app cannot start without the prod Firebase project. |

Codemagic builds what is pushed to GitHub (`origin`, `ahmedsukkary52-cmd/Rafiq-academy`). None of the uncommitted work in this worktree, including `codemagic.yaml` and the iOS flavor files, is visible there until it is committed and pushed, and that needs explicit approval.

Not added yet: an iOS signed workflow (`ios_signing` needs the bundle ID and an App Store Connect API key), store publishing, triggers. Flutter is pinned to 3.44.9 to match local development.

Owner steps:
1. Create a Codemagic account (sign in with GitHub) and grant it access to the repository only. Check the current free macOS build-minute allowance on Codemagic's pricing page.
2. Approve a commit and push of the release-preparation work to a branch.
3. Start `ios-unsigned-check` manually and share the log and artifacts.
4. Later: upload the keystore (§2), add the App Store Connect API key and the Google Play service account. Store publishing should stay manual until the release gates pass.

## 5. App icon and splash

Current assets are Flutter defaults:
- Android `mipmap-*/ic_launcher.png` unchanged since project creation, no adaptive icon.
- `launch_background.xml` is white.
- iOS `AppIcon.appiconset` is the Flutter icon; `LaunchImage` is a blank 68-byte placeholder.
- No notification icon: FCM falls back to the launcher icon, which Android draws as a white square.

Assets still needed from the owner or designer. No placeholder will be committed as final.

| Asset | Specification |
|---|---|
| Master app icon | 1024×1024 PNG, sRGB, square, **no transparency** (App Store rejects alpha), no rounded corners |
| Android adaptive icon | foreground 432×432 PNG with the logo inside the central 264×264 safe zone, plus a background colour or image; optional monochrome layer (Android 13 themed icons) |
| Android notification icon | white-on-transparent silhouette, 24dp (96×96 at xxxhdpi) |
| Play Store icon | 512×512 PNG, 32-bit, ≤ 1 MB |
| Play feature graphic | 1024×500 JPG or 24-bit PNG, no alpha |
| Splash | logo on a solid brand colour. Android 12+ system splash shows the icon in a circle (centre 192dp of 288dp); iOS launch screen is a storyboard with a centred logo |
| Brand colours | primary and splash background hex values |
| Store screenshots | phone screenshots in Arabic for Play (2–8) and App Store (6.9"); iPad 13" too if iPad stays supported |

Once the assets exist, generate the platform files with a generator (for example `flutter_launcher_icons`, `flutter_native_splash`) or by hand. Adding these dev dependencies needs approval for `pub get`.

## 6. Owner decisions and external inputs

| # | Item | Needed for |
|---|---|---|
| 1 | Create the prod Firebase project (and staging, if wanted), enable Blaze and budget alerts | B1, B2, B7 |
| 2 | Confirm Android prod ID `com.basmaacademy.app` (permanent after the first Play upload) | Play |
| 3 | Choose the iOS prod bundle ID; iPad support yes or no | App Store, §3 |
| 4 | Create and safeguard the upload keystore; Play App Signing | B8 |
| 5 | Apple Developer Program enrollment (an organisation needs a D-U-N-S number), team ID, APNs key | B9 |
| 6 | Google Play developer account | Play |
| 7 | Codemagic team and repository connection | CI |
| 8 | Icon, splash and store assets (§5) | Store submission |
| 9 | Privacy policy URL, support contact, data-safety form and App Privacy answers | Store submission |
| 10 | Codemagic macOS builds (no Mac purchase): account, repository access, approved push, first `ios-unsigned-check` run (§3.1, §4) | B9 |

## 7. Production project setup checklist

The prod project does not exist (B1). `rafiq-academy` stays the dev project
with seed and test data: no real user is provisioned there and its data is
never copied into prod.

**Decide first (owner):**

1. Project id. Ids are global; the repo assumes `rafiq-academy-prod`. If it
   is taken, every place in "Repository changes" below changes with it.
2. Firestore location (permanent; Functions run in `europe-west1`, so a
   European location close to it) and the default Storage bucket location.
3. Billing account, Blaze and budget alerts (`FIREBASE_BILLING_CHECKLIST.md`;
   Functions, the overdue scheduler and managed exports need Blaze).
4. Android prod id `com.basmaacademy.app` and the iOS prod bundle id (§6 items
   2–3).

**Console setup (owner, in the new project only):**

1. Create the Firestore database (Native mode) and the default Storage bucket.
2. Authentication: Email/Password on, self sign-up off, anonymous off, no other
   provider, email enumeration protection on, authorized domains reviewed
   (`B14_MEETING_LINKS.md` §7).
3. Register the Android app (with the SHA-1/SHA-256 of the upload key and of
   Play App Signing) and the iOS app; upload the APNs key.
4. IAM: deployers get only what deploys need; a separate service account per
   project for approved scripts; no prod credential on a machine set up for
   `rafiq-academy` scripts at the same time.
5. Budget alerts on the billing account.

**Repository changes (after the project exists; each has a test):**

| File | Change | Test |
|---|---|---|
| `.firebaserc` | `prod` alias value, only if the id differs | `functions/test/deploy_targets_contract.test.mjs` |
| `functions/scripts/deploy-functions.mjs` | `PROJECTS.prod` and the `CONFIRM_PROD_DEPLOY` token | `deploy_targets_contract`, `deploy_functions_wrapper` |
| `functions/scripts/migrate-guards.mjs` | `ALLOWED_PROJECTS` | `migrate_guards.test.mjs` |
| `functions/scripts/migrate-meeting-links.mjs` | `KNOWN_REAL_PROJECTS` (refusal list) | `migrate_meeting_links.test.mjs` |
| `lib/core/firebase/app_flavor.dart` | prod project id; `firebaseOptionsFor(AppFlavor.prod)` returns prod options, dev check kept | `test/core/app_flavor_test.dart` |
| prod `FirebaseOptions` (separate file, so `lib/firebase_options.dart` stays dev) | generated for the new project | `test/core/app_flavor_test.dart` |
| `android/app/src/prod/google-services.json` | prod Android config (`android/app/google-services.json` stays dev) | `flavor_config_contract_test.dart` |
| `ios/Flutter/Flavor-prod.xcconfig` | confirmed bundle id | `test/core/release/ios_flavor_contract_test.dart` |
| `firebase.json` `flutter.platforms` | add prod entries without replacing the dev ones | — |
| `functions/.env.prod` | `PRODUCTION_BACKEND_ENABLED=true` only after B-BILLING is Verified for prod | — |

`tool/seed_target.dart` stays emulator-only (`test/tool/seed_target_test.dart`
rejects every real target), so no seeder can reach either project.

**First deploy to prod:** indexes, then Functions
(`CONFIRM_PROD_DEPLOY=<prod id> npm run deploy:prod`), then Firestore rules,
then Storage rules, then `appConfig/clientVersion`. A new project has no
legacy meeting links or calendar events, so the `rafiq-academy` copy, strip
and backfill (`RELEASE_RUNBOOK_J10.md` §5) do not apply. Accounts are created
with `adminProvisionUser` only.

**Keeping `rafiq-academy` separate:** the dev flavor accepts only
`rafiq-academy` and prod never falls back to it (`app_flavor.dart`); the
deploy wrapper maps each alias to one project and refuses extra arguments;
real migration runs require a credential file whose `project_id` matches
`--project`. Distribute only dev builds (label `بصمة (تطوير)`) for this
project, and only to testers.

## 8. Dev workflow (Phase 2)

How to build, run and check the dev app without touching any other project.
There is no prod configuration in the repository, so no command here can
reach one.

**Toolchain.**

| Tool | Version | Source |
|---|---|---|
| Flutter | 3.44.9 (Dart `^3.11.1`) | `codemagic.yaml`, `pubspec.yaml` |
| JDK | 17 (CI); a newer local JDK also builds | `codemagic.yaml`; Gradle compiles for Java 17 |
| Node.js (Functions) | 22: the deployed runtime | `functions/package.json` `engines` |
| Firebase CLI | 15.x (15.18.0 used for the emulator runs) | — |

`npm test` in `functions/` passes on Node 22 and on Node 24. The preload
check for the runtime version runs on Node 22 directly; on another Node
version, set `B14_RUNTIME_NODE_BIN` to a Node 22 executable or it is skipped.
Deploys use Node 22 regardless of the local version.

**Run on the local emulators (no real project).**

```
cd functions && npm run serve          # demo-rafiq-rules only; refuses extra arguments
npm run seed:emulator                  # second terminal, functions/
flutter run --flavor dev --dart-define=USE_FIREBASE_EMULATOR=true
```

`USE_FIREBASE_EMULATOR=true` is refused in release and profile builds. The app
then uses a named Firebase app with fake keys for `demo-rafiq-rules`, and Auth,
Firestore, Functions and Storage on `127.0.0.1` (`lib/core/firebase/app_firebase.dart`).
On a physical Android phone, run `adb reverse tcp:<port> tcp:<port>` for 9099,
8080, 5001 and 9199. Debug emulator builds also turn off native FCM
auto-init, so the phone does not register a token with `rafiq-academy`.
Seed accounts: `docs/DEMO_ACADEMY_DATASET.md`.

**Run against `rafiq-academy` (test data only).** `flutter run --flavor dev`.
Until B-BILLING is closed and Functions are deployed with the backend switch
(`RELEASE_RUNBOOK_J10.md` §2), callables are absent or answer
`failed-precondition`. Firestore and Storage use the deployed rules.

**Builds.**

- Android: `flutter build apk --flavor dev --debug` (also Codemagic
  `android-dev-check`). `--flavor staging` and `--flavor prod` stop at the
  google-services step (no matching client), and a prod release without the
  upload key stops before any artifact (§2).
- iOS: only on macOS, through Codemagic `ios-unsigned-check` (§3.1, §4). An
  unsigned build proves compilation only, not distribution.

**What fails closed.** Missing or unknown flavor: the app throws at start.
Staging and prod: `firebaseOptionsFor` throws. Dev options for any project
other than `rafiq-academy`: the app throws. Emulator mode outside debug: the
app throws. Functions in the emulator: they refuse to start for a non-`demo-*`
project.

**Checks before handing over a dev build.**

| Check | Command |
|---|---|
| Analyzer | `flutter analyze --no-fatal-infos --no-fatal-warnings` |
| Flutter tests | `flutter test` |
| Flavor and release contracts only | `flutter test test/core` |
| Functions | `npm run build && npm test` in `functions/` (Node 22) |
| Firestore rules | `npx firebase emulators:exec --project demo-rafiq-rules --only firestore "npm --prefix rules_test run test:all:firestore"` |
| Storage rules | the same with `--only firestore,storage` (per the file headers) and `test:all:storage` |
| Functions suites outside `npm test` | `RELEASE_RUNBOOK_J10.md` §6 |
