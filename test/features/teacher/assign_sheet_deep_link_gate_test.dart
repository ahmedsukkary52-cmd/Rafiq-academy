import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/presentation/utils/assign_sheet_deep_link_gate.dart';

void main() {
  group('AssignSheetDeepLinkGate', () {
    test('disarmed gate never opens', () {
      final gate = AssignSheetDeepLinkGate(
        expectedHalaqaId: 'h1',
        armed: false,
      );

      expect(
        gate.onStudentsStatus(isLoaded: true, studentsHalaqaId: 'h1'),
        isFalse,
      );
    });

    test('does not open on stale roster from another halaqa', () {
      final gate = AssignSheetDeepLinkGate(expectedHalaqaId: 'h2', armed: true);

      expect(
        gate.onStudentsStatus(isLoaded: true, studentsHalaqaId: 'h1'),
        isFalse,
      );
      expect(
        gate.onStudentsStatus(isLoaded: true, studentsHalaqaId: null),
        isFalse,
      );
    });

    test('does not open while students are not loaded', () {
      final gate = AssignSheetDeepLinkGate(expectedHalaqaId: 'h1', armed: true);

      expect(
        gate.onStudentsStatus(isLoaded: false, studentsHalaqaId: 'h1'),
        isFalse,
      );
    });

    test('opens once when loaded roster matches expected halaqa', () {
      final gate = AssignSheetDeepLinkGate(expectedHalaqaId: 'h1', armed: true);

      expect(
        gate.onStudentsStatus(isLoaded: true, studentsHalaqaId: 'h1'),
        isTrue,
      );
      expect(
        gate.onStudentsStatus(isLoaded: true, studentsHalaqaId: 'h1'),
        isFalse,
        reason: 'second observation must not open again',
      );
      expect(gate.hasOpened, isTrue);
    });
  });
}
