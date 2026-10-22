import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _flavors = ['dev', 'prod'];
const _modes = ['Debug', 'Release', 'Profile'];

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String? _setting(String xcconfig, String key) => RegExp(
  '^$key\\s*=\\s*(.+?)\\s*\$',
  multiLine: true,
).firstMatch(xcconfig)?.group(1);

String? _androidLabel(String gradle, String flavor) => RegExp(
  'create\\("$flavor"\\)\\s*\\{[^}]*resValue\\("string",\\s*"app_name",\\s*"([^"]*)"\\)',
).firstMatch(gradle)?.group(1);

void main() {
  final gradle = _read('android/app/build.gradle.kts');

  test('dev keeps the iOS bundle ID registered in rafiq-academy', () {
    final registered = RegExp(
      r"iosBundleId:\s*'([^']+)'",
    ).firstMatch(_read('lib/firebase_options.dart'))?.group(1);
    expect(registered, isNotNull);
    expect(
      _setting(
        _read('ios/Flutter/Flavor-dev.xcconfig'),
        'PRODUCT_BUNDLE_IDENTIFIER',
      ),
      registered,
    );
  });

  test('prod has its own bundle ID', () {
    final dev = _setting(
      _read('ios/Flutter/Flavor-dev.xcconfig'),
      'PRODUCT_BUNDLE_IDENTIFIER',
    );
    final prod = _setting(
      _read('ios/Flutter/Flavor-prod.xcconfig'),
      'PRODUCT_BUNDLE_IDENTIFIER',
    );
    expect(prod, isNotNull);
    expect(prod, isNot(dev));
  });

  test('iOS display names match the Android flavor labels', () {
    for (final flavor in _flavors) {
      expect(
        _setting(
          _read('ios/Flutter/Flavor-$flavor.xcconfig'),
          'APP_DISPLAY_NAME',
        ),
        _androidLabel(gradle, flavor),
        reason: flavor,
      );
    }
  });

  test('each flavored configuration includes its Pods, Flutter and flavor '
      'settings', () {
    for (final flavor in _flavors) {
      for (final mode in _modes) {
        final name = '$mode-$flavor';
        final lines = File(
          'ios/Flutter/$name.xcconfig',
        ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();
        expect(lines, [
          '#include? "Pods/Target Support Files/Pods-Runner/'
              'Pods-Runner.${name.toLowerCase()}.xcconfig"',
          '#include "Generated.xcconfig"',
          '#include "Flavor-$flavor.xcconfig"',
        ], reason: name);
      }
    }
  });

  test('Info.plist takes the display name from the build configuration', () {
    expect(
      _read('ios/Runner/Info.plist'),
      contains(
        '<key>CFBundleDisplayName</key>\n\t<string>\$(APP_DISPLAY_NAME)</string>',
      ),
    );
    for (final base in ['Debug', 'Release']) {
      expect(
        _setting(_read('ios/Flutter/$base.xcconfig'), 'APP_DISPLAY_NAME'),
        'بصمة',
        reason: '$base.xcconfig (unflavored builds)',
      );
    }
  });

  test('Podfile maps every configuration and targets iOS 13', () {
    final podfile = _read('ios/Podfile');
    expect(podfile, contains("platform :ios, '13.0'"));
    for (final mode in _modes) {
      final type = mode == 'Debug' ? ':debug' : ':release';
      expect(podfile, contains("'$mode' => $type"));
      for (final flavor in _flavors) {
        expect(podfile, contains("'$mode-$flavor' => $type"));
      }
    }
  });

  test('the flavor script configures the same flavors and modes', () {
    final script = _read('ios/scripts/configure_flavors.rb');
    expect(script, contains('FLAVORS = %w[${_flavors.join(' ')}].freeze'));
    expect(script, contains('MODES = %w[${_modes.join(' ')}].freeze'));
  });

  test('Codemagic adds the flavors before building iOS, unsigned', () {
    final yaml = _read('codemagic.yaml');
    final configure = yaml.indexOf('ruby ios/scripts/configure_flavors.rb');
    expect(configure, isNonNegative);
    for (final flavor in _flavors) {
      final build = yaml.indexOf(
        'flutter build ios --flavor $flavor --release --no-codesign',
      );
      expect(build, greaterThan(configure), reason: flavor);
    }
    expect(yaml, isNot(contains('ios_signing:')));
  });
}
