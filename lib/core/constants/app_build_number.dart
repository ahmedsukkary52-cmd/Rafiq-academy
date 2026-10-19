/// Build number of this app binary: the integer after `+` in the
/// `pubspec.yaml` `version` field (Android `versionCode`, iOS
/// `CFBundleVersion`). The minimum-version gate (B10) compares it with
/// `appConfig/clientVersion.minimumBuildNumber`.
///
/// Release procedure: bump the `+N` in `pubspec.yaml` and this constant
/// together (`test/core/constants/app_build_number_test.dart` fails if they
/// differ). Do not pass `--build-number` to `flutter build` unless this
/// constant is changed to the same value; otherwise the store build number
/// and the gate's number disagree.
const int kAppBuildNumber = 1;
