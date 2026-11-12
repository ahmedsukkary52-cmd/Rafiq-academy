import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/firebase/app_firebase.dart';

void main() {
  group('emulator endpoints', () {
    test('callables target the deployed region', () {
      expect(functionsRegion, 'europe-west1');
    });

    test('every service is wired without Android host rewriting', () {
      final source = File(
        'lib/core/firebase/app_firebase.dart',
      ).readAsStringSync();
      for (final call in [
        'useAuthEmulator(',
        'useFirestoreEmulator(',
        'useFunctionsEmulator(',
        'useStorageEmulator(',
      ]) {
        expect(source, contains(call), reason: call);
      }
      expect('automaticHostMapping: false'.allMatches(source).length, 4);
    });

    test('debug builds allow cleartext only to the loopback emulators', () {
      final config = File(
        'android/app/src/debug/res/xml/debug_network_security_config.xml',
      ).readAsStringSync();
      final domains = RegExp(
        r'<domain[^>]*>([^<]+)</domain>',
      ).allMatches(config).map((m) => m.group(1)).toList();
      expect(domains, ['127.0.0.1']);
      expect(config, isNot(contains('<base-config')));
    });
  });
}
