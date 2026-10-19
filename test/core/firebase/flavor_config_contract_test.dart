import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/firebase/app_flavor.dart';

const _devApplicationId = 'com.example.rafiq_academy';
const _prodApplicationId = 'com.basmaacademy.app';

/// Index of the `}` closing the block whose body starts at [bodyStart].
int _closingBrace(String source, int bodyStart) {
  var depth = 1;
  for (var i = bodyStart; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}' && --depth == 0) return i;
  }
  throw StateError('Unclosed block at offset $bodyStart');
}

/// Body of the first top-level `<name> { ... }` block in [gradle].
String _blockBody(String gradle, String name) {
  final open = RegExp('\\b$name\\s*\\{').firstMatch(gradle);
  if (open == null) throw StateError('No $name block');
  return gradle.substring(open.end, _closingBrace(gradle, open.end));
}

/// `create("<flavor>") { ... }` blocks directly inside `productFlavors`, so
/// `create(...)` in other blocks (signingConfigs, ...) is ignored.
Map<String, String> _gradleFlavorBlocks(String gradle) {
  final body = _blockBody(gradle, 'productFlavors');
  final create = RegExp(r'create\("(\w+)"\)\s*\{');
  final flavors = <String, String>{};
  var from = 0;
  while (true) {
    final matches = create.allMatches(body, from);
    if (matches.isEmpty) return flavors;
    final match = matches.first;
    final end = _closingBrace(body, match.end);
    flavors[match.group(1)!] = body.substring(match.end, end);
    from = end + 1;
  }
}

String? _applicationId(String block) =>
    RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(block)?.group(1);

String? _appName(String block) => RegExp(
  r'resValue\("string",\s*"app_name",\s*"([^"]*)"\)',
).firstMatch(block)?.group(1);

void main() {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final flavors = _gradleFlavorBlocks(gradle);

  test('pubspec default flavor is dev', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^\s+default-flavor:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match?.group(1), 'dev');
  });

  test('flavor parsing ignores create blocks outside productFlavors', () {
    const sample = '''
android {
    signingConfigs {
        create("release") { storeFile = file("x") }
    }
    productFlavors {
        create("a") {
            ndk { abiFilters += "arm64-v8a" }
            applicationId = "app.a"
        }
    }
}
''';
    final parsed = _gradleFlavorBlocks(sample);
    expect(parsed.keys, ['a']);
    expect(_applicationId(parsed['a']!), 'app.a');
  });

  test('Gradle flavors match AppFlavor', () {
    expect(flavors.keys.toSet(), AppFlavor.values.map((f) => f.name).toSet());
  });

  test('every Gradle flavor declares a unique applicationId and app_name', () {
    final ids = <String>[];
    for (final MapEntry(key: name, value: block) in flavors.entries) {
      final id = _applicationId(block);
      expect(id, isNotNull, reason: '$name must set applicationId');
      expect(_appName(block), isNotNull, reason: '$name must set app_name');
      ids.add(id!);
    }
    expect(ids.toSet().length, ids.length, reason: 'applicationIds: $ids');
  });

  test('Gradle flavors set the expected application IDs and app names', () {
    expect(_applicationId(flavors['dev']!), _devApplicationId);
    expect(_appName(flavors['dev']!), 'بصمة (تطوير)');
    expect(_applicationId(flavors['prod']!), _prodApplicationId);
    expect(_appName(flavors['prod']!), 'بصمة');
  });

  test('defaultConfig leaves the application ID to the flavors', () {
    expect(_applicationId(_blockBody(gradle, 'defaultConfig')), isNull);
  });

  test('AndroidManifest label comes from the flavor app_name', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:label="@string/app_name"'));
  });

  test('committed google-services.json is the dev project only', () {
    final json =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final projectInfo = json['project_info'] as Map<String, dynamic>;
    final packageNames = [
      for (final client in json['client'] as List<dynamic>)
        ((client as Map<String, dynamic>)['client_info']
                as Map<String, dynamic>)['android_client_info']['package_name']
            as String,
    ];

    expect(projectInfo['project_id'], devFirebaseProjectId);
    expect(packageNames, contains(_devApplicationId));
    expect(
      packageNames.where((name) => name.startsWith(_prodApplicationId)),
      isEmpty,
      reason:
          'prod and staging app IDs must not be registered in the dev '
          'project config',
    );
  });
}
