import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/shared/domain/academy_membership_observation.dart';

void main() {
  group('AcademyMembershipObservation (Rule 8 / Dual-Halaqa)', () {
    test('fromInvariant — established without profile match', () {
      expect(
        AcademyMembershipObservations.fromInvariant(
          rosterContainsStudent: true,
          role: AppRoles.student,
          isActive: true,
        ),
        AcademyMembershipObservation.established,
      );
    });

    test('fromInvariant — notEstablished when roster missing', () {
      expect(
        AcademyMembershipObservations.fromInvariant(
          rosterContainsStudent: false,
          role: AppRoles.student,
          isActive: true,
        ),
        AcademyMembershipObservation.notEstablished,
      );
    });

    test('isActive alone never yields established', () {
      expect(
        AcademyMembershipObservations.fromInvariant(
          rosterContainsStudent: false,
          role: AppRoles.student,
          isActive: true,
        ),
        AcademyMembershipObservation.notEstablished,
      );
    });

    test('student facing — primary pointer maps to two states only', () {
      expect(
        AcademyMembershipObservations.forStudentFacing('h1'),
        AcademyMembershipObservation.established,
      );
      expect(
        AcademyMembershipObservations.forStudentFacing(null),
        AcademyMembershipObservation.notEstablished,
      );
      expect(
        AcademyMembershipObservations.forStudentFacing('  '),
        AcademyMembershipObservation.notEstablished,
      );
    });

    test('day-ops roster member — on/off roster only', () {
      expect(
        AcademyMembershipObservations.forDayOpsRosterMember(
          halaqaStudentIds: const ['s1', 's2'],
          studentId: 's1',
        ),
        AcademyMembershipObservation.established,
      );
      expect(
        AcademyMembershipObservations.forDayOpsRosterMember(
          halaqaStudentIds: const ['s2'],
          studentId: 's1',
        ),
        AcademyMembershipObservation.notEstablished,
      );
    });
  });
}
