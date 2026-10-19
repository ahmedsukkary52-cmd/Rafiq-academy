import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/app_update/domain/client_version_config.dart';

ClientVersionConfigParse parse(Map<String, dynamic> data) =>
    parseClientVersionConfig(data);

String? invalidField(Map<String, dynamic> data) => switch (parse(data)) {
  InvalidClientVersionConfig(:final field) => field,
  ValidClientVersionConfig() => null,
};

ClientVersionConfig valid(Map<String, dynamic> data) => switch (parse(data)) {
  ValidClientVersionConfig(:final config) => config,
  InvalidClientVersionConfig(:final field) => fail('invalid $field'),
};

void main() {
  group('meetsMinimumBuild', () {
    test('below, equal and above the minimum', () {
      expect(meetsMinimumBuild(installedBuild: 4, minimumBuild: 5), isFalse);
      expect(meetsMinimumBuild(installedBuild: 5, minimumBuild: 5), isTrue);
      expect(meetsMinimumBuild(installedBuild: 6, minimumBuild: 5), isTrue);
    });
  });

  group('parseClientVersionConfig minimumBuildNumber', () {
    test('accepts integers from 1 to the store limit', () {
      expect(valid({'minimumBuildNumber': 1}).minimumBuildNumber, 1);
      expect(
        valid({'minimumBuildNumber': maxClientBuildNumber}).minimumBuildNumber,
        maxClientBuildNumber,
      );
    });

    test('rejects missing, non-integer and out-of-range values', () {
      for (final value in <Object?>[
        null,
        0,
        -1,
        maxClientBuildNumber + 1,
        2.0,
        2.5,
        '2',
        true,
      ]) {
        expect(
          invalidField({'minimumBuildNumber': value}),
          'minimumBuildNumber',
          reason: '$value',
        );
      }
      expect(invalidField({}), 'minimumBuildNumber');
    });

    test('ignores unknown fields', () {
      expect(
        valid({'minimumBuildNumber': 3, 'updatedAt': 'x'}),
        const ClientVersionConfig(minimumBuildNumber: 3),
      );
    });
  });

  group('parseClientVersionConfig update URLs', () {
    test('absent, null or empty URLs mean not configured', () {
      final config = valid({
        'minimumBuildNumber': 2,
        'androidUpdateUrl': null,
        'iosUpdateUrl': '  ',
      });
      expect(config.androidUpdateUrl, isNull);
      expect(config.iosUpdateUrl, isNull);
    });

    test('valid HTTPS URLs are kept per platform', () {
      final config = valid({
        'minimumBuildNumber': 2,
        'androidUpdateUrl': ' https://play.example.com/app ',
        'iosUpdateUrl': 'https://apps.example.com/app',
      });
      expect(
        config.updateUrlFor(TargetPlatform.android),
        Uri.parse('https://play.example.com/app'),
      );
      expect(
        config.updateUrlFor(TargetPlatform.iOS),
        Uri.parse('https://apps.example.com/app'),
      );
      expect(config.updateUrlFor(TargetPlatform.windows), isNull);
    });

    test('an invalid configured URL makes the document invalid', () {
      for (final url in <Object>[
        'http://play.example.com/app',
        'https://',
        'https:///path',
        'https://user:pw@example.com/app',
        'javascript:alert(1)',
        'market://details?id=x',
        'not a url',
        42,
        'https://example.com/${'a' * 2100}',
      ]) {
        expect(
          invalidField({'minimumBuildNumber': 2, 'androidUpdateUrl': url}),
          'androidUpdateUrl',
          reason: '$url',
        );
        expect(
          invalidField({'minimumBuildNumber': 2, 'iosUpdateUrl': url}),
          'iosUpdateUrl',
          reason: '$url',
        );
      }
    });
  });
}
