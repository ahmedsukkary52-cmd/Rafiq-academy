import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final queries = RegExp(
    r'<queries>([\s\S]*?)</queries>',
  ).firstMatch(manifest)?.group(1);

  test('web links can be checked with canLaunchUrl on Android 11+', () {
    expect(queries, isNotNull);
    for (final scheme in ['https', 'http']) {
      expect(
        queries,
        matches(
          RegExp(
            '<intent>\\s*<action android:name="android.intent.action.VIEW" />'
            '\\s*<data android:scheme="$scheme" />\\s*</intent>',
          ),
        ),
        reason: scheme,
      );
    }
  });

  test('plugin-merged storage and media permissions are removed', () {
    for (final permission in [
      'READ_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
    ]) {
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.$permission" '
          'tools:node="remove" />',
        ),
        reason: permission,
      );
    }
    expect(
      manifest,
      contains('xmlns:tools="http://schemas.android.com/tools"'),
    );
  });

  test('microphone permission and push channel stay declared', () {
    expect(
      manifest,
      contains('android:name="android.permission.RECORD_AUDIO"'),
    );
    expect(
      manifest,
      contains(
        'android:name="com.google.firebase.messaging.default_notification_channel_id"',
      ),
    );
    expect(manifest, contains('android:value="basma_general"'));
  });
}
