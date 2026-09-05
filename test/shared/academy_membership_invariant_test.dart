import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/shared/domain/academy_membership_invariant.dart';

void main() {
  group('AcademyMembershipInvariant (Dual-Halaqa)', () {
    test('isComplete when roster + student role + isActive', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          role: AppRoles.student,
          isActive: true,
        ),
        isTrue,
      );
    });

    test('incomplete when roster missing', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: false,
          role: AppRoles.student,
          isActive: true,
        ),
        isFalse,
      );
    });

    test('profile pointer is not required for completeness', () {
      // Dual-Halaqa: student may be on roster H2 while primary remains H1.
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          role: AppRoles.student,
          isActive: true,
        ),
        isTrue,
      );
    });

    test('incomplete when role is not student', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          role: AppRoles.teacher,
          isActive: true,
        ),
        isFalse,
      );
    });

    test('incomplete when isActive is not true', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          role: AppRoles.student,
          isActive: false,
        ),
        isFalse,
      );
    });

    test('maxHalaqatPerStudent is 2', () {
      expect(AcademyMembershipInvariant.maxHalaqatPerStudent, 2);
    });
  });

  group('primary rules', () {
    test('first membership sets primary when empty', () {
      expect(
        AcademyMembershipInvariant.shouldSetPrimaryOnEstablish(
          currentPrimary: null,
          membershipHalaqaIdsExcludingTarget: const [],
        ),
        isTrue,
      );
    });

    test('first membership sets primary even with orphan pointer', () {
      expect(
        AcademyMembershipInvariant.shouldSetPrimaryOnEstablish(
          currentPrimary: 'stale-orphan',
          membershipHalaqaIdsExcludingTarget: const [],
        ),
        isTrue,
      );
    });

    test('add-second does not set primary', () {
      expect(
        AcademyMembershipInvariant.shouldSetPrimaryOnEstablish(
          currentPrimary: 'h1',
          membershipHalaqaIdsExcludingTarget: const ['h1'],
        ),
        isFalse,
      );
    });

    test('transfer from primary → target becomes primary', () {
      expect(
        AcademyMembershipInvariant.primaryAfterTransfer(
          currentPrimary: 'h1',
          sourceHalaqaId: 'h1',
          targetHalaqaId: 'h2',
        ),
        'h2',
      );
    });

    test('transfer from non-primary → primary unchanged', () {
      expect(
        AcademyMembershipInvariant.primaryAfterTransfer(
          currentPrimary: 'h1',
          sourceHalaqaId: 'h2',
          targetHalaqaId: 'h3',
        ),
        'h1',
      );
    });

    test('last membership clears orphan primary', () {
      expect(
        AcademyMembershipInvariant.primaryAfterMembershipsChanged(
          currentPrimary: 'h1',
          remainingHalaqaIds: const [],
        ),
        isNull,
      );
    });

    test('orphan primary rebinds to a remaining membership', () {
      expect(
        AcademyMembershipInvariant.primaryAfterMembershipsChanged(
          currentPrimary: 'h-gone',
          remainingHalaqaIds: const ['h2', 'h1'],
        ),
        'h1',
      );
    });
  });
}
