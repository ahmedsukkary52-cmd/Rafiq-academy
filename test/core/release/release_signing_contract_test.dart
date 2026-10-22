import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Body of the `create("<flavor>") { ... }` block in [gradle].
String _flavorBlock(String gradle, String flavor) {
  final open = RegExp('create\\("$flavor"\\)\\s*\\{').firstMatch(gradle);
  if (open == null) throw StateError('No $flavor flavor');
  var depth = 1;
  for (var i = open.end; i < gradle.length; i++) {
    if (gradle[i] == '{') depth++;
    if (gradle[i] == '}' && --depth == 0) {
      return gradle.substring(open.end, i);
    }
  }
  throw StateError('Unclosed $flavor flavor');
}

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('prod is signed only with the upload key, never the debug key', () {
    final prod = _flavorBlock(gradle, 'prod');
    expect(prod, contains('signingConfigs.getByName("upload")'));
    expect(prod, isNot(contains('"debug"')));
  });

  test('dev and staging stay on the debug key', () {
    for (final flavor in ['dev', 'staging']) {
      expect(
        _flavorBlock(gradle, flavor),
        contains('signingConfig = signingConfigs.getByName("debug")'),
        reason: flavor,
      );
    }
  });

  test('the release build type does not force a signing config', () {
    final release = RegExp(
      r'release\s*\{([^}]*)\}',
    ).firstMatch(gradle.substring(gradle.indexOf('buildTypes')));
    expect(release, isNotNull);
    expect(release!.group(1), isNot(contains('signingConfig')));
  });

  test('a prod release without an upload key stops the build', () {
    expect(gradle, contains('gradle.taskGraph.whenReady'));
    expect(
      gradle,
      contains('Regex("^(assemble|bundle|package|install)ProdRelease.*")'),
    );
    expect(
      gradle,
      contains('!hasUploadKey && allTasks.any { prodReleaseArtifactTask'),
    );
    expect(gradle, contains('throw GradleException('));
  });

  test(
    'upload key material comes only from key.properties or CI variables',
    () {
      expect(gradle, contains('rootProject.file("key.properties")'));
      for (final name in [
        'CM_KEYSTORE_PATH',
        'CM_KEYSTORE_PASSWORD',
        'CM_KEY_ALIAS',
        'CM_KEY_PASSWORD',
      ]) {
        expect(gradle, contains('System.getenv("$name")'));
      }
      expect(
        RegExp(r'(storePassword|keyPassword)\s*=\s*"').hasMatch(gradle),
        isFalse,
        reason: 'no literal passwords in Gradle',
      );
    },
  );

  test('keystores and key.properties are git-ignored', () {
    final ignore = File('android/.gitignore').readAsLinesSync();
    expect(
      ignore,
      containsAll(['key.properties', '**/*.jks', '**/*.keystore']),
    );
  });

  group('codemagic.yaml', () {
    final yaml = File('codemagic.yaml').readAsStringSync();
    final commands = yaml
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('#'))
        .join('\n');

    test('never overrides the build number checked by the version gate', () {
      expect(commands, isNot(contains('--build-number')));
      expect(commands, isNot(contains('--build-name')));
    });

    test('references signing by name and holds no secrets', () {
      expect(yaml, contains('android_signing:'));
      expect(
        RegExp(
          r'(PASSWORD|password|keystore_password|private_key)\s*:',
        ).hasMatch(yaml),
        isFalse,
      );
    });

    test('has no automatic triggers or publishing', () {
      expect(yaml, isNot(contains('triggering:')));
      expect(yaml, isNot(contains('publishing:')));
    });

    test('prod builds use the prod flavor and dev builds the dev flavor', () {
      expect(yaml, contains('flutter build appbundle --flavor prod --release'));
      expect(yaml, contains('flutter build apk --flavor dev --debug'));
      expect(
        yaml,
        contains('flutter build ios --flavor dev --release --no-codesign'),
      );
    });
  });
}
