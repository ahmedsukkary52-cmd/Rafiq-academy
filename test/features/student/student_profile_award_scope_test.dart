import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/student/domain/student_profile_award_scope.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/services/halaqa_student_summary_projector.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  group('resolveStudentProfileAwardHalaqaId', () {
    test('Class Details halaqaId takes precedence over selectedHalaqaId', () {
      const selectedHalaqaId = 'halaqa-selected';
      final resolved = resolveStudentProfileAwardHalaqaId(
        routeHalaqaId: 'halaqa-class',
        profileHalaqaId: 'halaqa-profile',
      );
      expect(resolved, 'halaqa-class');
      expect(resolved, isNot(selectedHalaqaId));
    });

    test('falls back to profile.halaqaId when no route halaqa is provided', () {
      expect(
        resolveStudentProfileAwardHalaqaId(
          routeHalaqaId: null,
          profileHalaqaId: 'halaqa-profile',
        ),
        'halaqa-profile',
      );
      expect(
        resolveStudentProfileAwardHalaqaId(
          routeHalaqaId: '  ',
          profileHalaqaId: 'halaqa-profile',
        ),
        'halaqa-profile',
      );
    });

    test('ignores blank profile id when route id is present', () {
      expect(
        resolveStudentProfileAwardHalaqaId(
          routeHalaqaId: 'h-from-class',
          profileHalaqaId: '',
        ),
        'h-from-class',
      );
    });
  });

  group('AppRoutes.teacherStudentProfile', () {
    test('includes Class Details halaqaId as a query parameter', () {
      expect(
        AppRoutes.teacherStudentProfile('s1', halaqaId: 'h-class'),
        '/teacher/student/s1?halaqaId=h-class',
      );
    });

    test('omits query when opened without a class halaqa', () {
      expect(AppRoutes.teacherStudentProfile('s1'), '/teacher/student/s1');
    });
  });

  group('level and attendance sources', () {
    test('attendance percent uses the roster projector policy', () {
      final now = DateTime(2026, 8, 14, 12);
      final marks = [
        AttendanceMarkRef(
          id: '1',
          halaqaId: 'h1',
          studentId: 's1',
          date: now.subtract(const Duration(days: 1)),
          status: AttendancePolicy.statusPresent,
        ),
        AttendanceMarkRef(
          id: '2',
          halaqaId: 'h1',
          studentId: 's1',
          date: now.subtract(const Duration(days: 2)),
          status: AttendancePolicy.statusAbsent,
        ),
        AttendanceMarkRef(
          id: '3',
          halaqaId: 'h1',
          studentId: 's1',
          date: now.subtract(const Duration(days: 3)),
          status: AttendancePolicy.statusLate,
        ),
        AttendanceMarkRef(
          id: '4',
          halaqaId: 'h1',
          studentId: 's1',
          date: now.subtract(const Duration(days: 4)),
          status: AttendancePolicy.statusExcused,
        ),
      ];
      final projected = HalaqaStudentSummaryProjector.enrich(
        base: const HalaqaStudentSummaryEntity(
          uid: 's1',
          name: 'أحمد',
          level: 3,
        ),
        attendanceMarks: marks,
        recitations: const [],
        now: now,
      );
      expect(
        projected.attendancePercent,
        AttendancePolicy.attendancePercentFromStatuses(
          AttendancePolicy.uniqueDayStatuses(
            marks.where((m) => !m.date.isBefore(
              now.subtract(
                const Duration(
                  days: HalaqaStudentSummaryProjector.attendanceWindowDays,
                ),
              ),
            )),
          ),
        ),
      );
      expect(projected.level, 3);
      expect(
        attendancePercentFromRoster(roster: [projected], studentId: 's1'),
        projected.attendancePercent,
      );
    });

    test('level comes from the existing student profile/roster field', () {
      const roster = [
        HalaqaStudentSummaryEntity(uid: 's1', name: 'أحمد', level: 3),
      ];
      expect(roster.first.level, 3);
      expect(
        attendancePercentFromRoster(roster: roster, studentId: 'missing'),
        isNull,
      );
    });
  });
}
