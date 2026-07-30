import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/shared/domain/academy_membership_invariant.dart';

void main() {
  group('AcademyMembershipInvariant', () {
    test('isComplete only when all D-W8-7 members hold together', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          profileHalaqaId: 'h1',
          expectedHalaqaId: 'h1',
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
          profileHalaqaId: 'h1',
          expectedHalaqaId: 'h1',
          role: AppRoles.student,
          isActive: true,
        ),
        isFalse,
      );
    });

    test('incomplete when profile pointer drifts', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          profileHalaqaId: 'other',
          expectedHalaqaId: 'h1',
          role: AppRoles.student,
          isActive: true,
        ),
        isFalse,
      );
    });

    test('incomplete when role is not student', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          profileHalaqaId: 'h1',
          expectedHalaqaId: 'h1',
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
          profileHalaqaId: 'h1',
          expectedHalaqaId: 'h1',
          role: AppRoles.student,
          isActive: false,
        ),
        isFalse,
      );
    });

    test('Rule 6 — complete result is stable under repeated evaluation', () {
      bool evaluate() => AcademyMembershipInvariant.isComplete(
        rosterContainsStudent: true,
        profileHalaqaId: 'h1',
        expectedHalaqaId: 'h1',
        role: AppRoles.student,
        isActive: true,
      );
      expect(evaluate(), isTrue);
      expect(evaluate(), isTrue);
      expect(evaluate(), evaluate());
    });
  });
}
