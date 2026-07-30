import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/shared/domain/academy_membership_consumption.dart';
import 'package:rafiq_academy/shared/domain/academy_membership_invariant.dart';
import 'package:rafiq_academy/shared/domain/halaqa_day_readiness.dart';

/// Slice 2 — operational readiness after Academy Admission (Rules 5–7).
void main() {
  const studentId = 's1';
  const halaqaId = 'h1';

  group('AcademyMembershipConsumption', () {
    test(
      'day-ops roster uses halaqa.studentIds without inventing membership',
      () {
        final roster = AcademyMembershipConsumption.dayOpsRosterStudentIds([
          studentId,
          '  ',
          's2',
        ]);
        expect(roster, ['s1', 's2']);
      },
    );

    test('student-facing pointer uses profile.halaqaId only', () {
      expect(
        AcademyMembershipConsumption.studentFacingHalaqaId(halaqaId),
        halaqaId,
      );
      expect(AcademyMembershipConsumption.studentFacingHalaqaId(null), isNull);
      expect(AcademyMembershipConsumption.studentFacingHalaqaId('  '), isNull);
    });

    test('login gate alone is not membership', () {
      expect(AcademyMembershipConsumption.loginGateAllows(true), isTrue);
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: false,
          profileHalaqaId: null,
          expectedHalaqaId: halaqaId,
          role: AppRoles.student,
          isActive: true,
        ),
        isFalse,
      );
    });
  });

  group('operational readiness after complete invariant', () {
    test('teacher/W3 roster input includes admitted student', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          profileHalaqaId: halaqaId,
          expectedHalaqaId: halaqaId,
          role: AppRoles.student,
          isActive: true,
        ),
        isTrue,
      );

      final roster = AcademyMembershipConsumption.dayOpsRosterStudentIds([
        studentId,
      ]);
      expect(roster, contains(studentId));

      final readiness = HalaqaDayReadinessProjector.project(
        rosterStudentIds: roster,
        markedStudentIds: const [],
        now: DateTime(2024, 6, 3, 9),
        latestAssignmentDueDate: null,
        pendingReviewCount: 0,
      );
      expect(readiness.needsAttention, isTrue);
      expect(readiness.gaps.first.kind, HalaqaDayGapKind.attendanceIncomplete);
      expect(readiness.gaps.first.quantity, 1);
    });

    test('student home can resolve halaqa from profile pointer', () {
      expect(
        AcademyMembershipConsumption.studentFacingHalaqaId(halaqaId),
        halaqaId,
      );
    });

    test('incomplete membership leaves student pointer unset', () {
      expect(
        AcademyMembershipInvariant.isComplete(
          rosterContainsStudent: true,
          profileHalaqaId: null,
          expectedHalaqaId: halaqaId,
          role: AppRoles.student,
          isActive: true,
        ),
        isFalse,
      );
      expect(AcademyMembershipConsumption.studentFacingHalaqaId(null), isNull);
    });
  });

  group('Rule 7 — invariant-driven (not field-copy)', () {
    test(
      'admission targets are evaluated as a set, not derived from one field',
      () {
        // Roster alone is not authority to imply profile (no copy roster → profile).
        expect(
          AcademyMembershipInvariant.isComplete(
            rosterContainsStudent: true,
            profileHalaqaId: null,
            expectedHalaqaId: halaqaId,
            role: AppRoles.student,
            isActive: true,
          ),
          isFalse,
        );
        // Profile alone is not authority to imply roster (no copy profile → roster).
        expect(
          AcademyMembershipInvariant.isComplete(
            rosterContainsStudent: false,
            profileHalaqaId: halaqaId,
            expectedHalaqaId: halaqaId,
            role: AppRoles.student,
            isActive: true,
          ),
          isFalse,
        );
      },
    );
  });
}
