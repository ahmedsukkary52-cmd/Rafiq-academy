import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/firebase/app_flavor.dart';

void main() {
  group('parseAppFlavor', () {
    test('accepts dev, staging, trial and prod', () {
      expect(parseAppFlavor('dev'), AppFlavor.dev);
      expect(parseAppFlavor('staging'), AppFlavor.staging);
      expect(parseAppFlavor('trial'), AppFlavor.trial);
      expect(parseAppFlavor('prod'), AppFlavor.prod);
    });

    test('refuses to guess a missing or unknown flavor', () {
      expect(() => parseAppFlavor(null), throwsStateError);
      expect(() => parseAppFlavor(''), throwsStateError);
      expect(() => parseAppFlavor('stage'), throwsStateError);
      expect(() => parseAppFlavor('Staging'), throwsStateError);
      expect(() => parseAppFlavor('Dev'), throwsStateError);
    });
  });

  group('local flavors are Emulator-only (Basma isolation)', () {
    test('dev and staging are local; trial and prod are not', () {
      expect(isLocalFlavor(AppFlavor.dev), isTrue);
      expect(isLocalFlavor(AppFlavor.staging), isTrue);
      expect(isLocalFlavor(AppFlavor.trial), isFalse);
      expect(isLocalFlavor(AppFlavor.prod), isFalse);
    });

    test('the only local project is the fake demo project', () {
      expect(localEmulatorProjectId, 'demo-rafiq-rules');
      expect(localEmulatorProjectId, startsWith('demo-'));
    });
  });
}
