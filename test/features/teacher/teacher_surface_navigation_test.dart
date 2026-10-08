import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/teacher/presentation/utils/teacher_surface_navigation.dart';

void main() {
  group('Class Details student card actions', () {
    test('teacher keeps profile, evaluate and award on a regular student', () {
      expect(
        TeacherSurfaceNavigation.studentCardActions(
          role: AppRoles.teacher,
          isAtRisk: false,
        ),
        [
          StudentCardAction.profile,
          StudentCardAction.evaluate,
          StudentCardAction.award,
        ],
      );
    });

    test('teacher keeps profile, evaluate and contact parent when at risk', () {
      expect(
        TeacherSurfaceNavigation.studentCardActions(
          role: AppRoles.teacher,
          isAtRisk: true,
        ),
        [
          StudentCardAction.profile,
          StudentCardAction.evaluate,
          StudentCardAction.contactParent,
        ],
      );
    });

    test('supervisor is not offered the teacher-only profile route', () {
      final actions = TeacherSurfaceNavigation.studentCardActions(
        role: AppRoles.supervisor,
        isAtRisk: false,
      );
      expect(actions, [StudentCardAction.evaluate, StudentCardAction.award]);
    });

    test('supervisor is not offered profile or parent chat when at risk', () {
      final actions = TeacherSurfaceNavigation.studentCardActions(
        role: AppRoles.supervisor,
        isAtRisk: true,
      );
      expect(actions, [StudentCardAction.evaluate]);
    });

    test('every offered destination is one the router allows for the role', () {
      for (final role in [AppRoles.teacher, AppRoles.supervisor]) {
        for (final atRisk in [true, false]) {
          final actions = TeacherSurfaceNavigation.studentCardActions(
            role: role,
            isAtRisk: atRisk,
          );
          final paths = {
            StudentCardAction.profile: AppRoutes.teacherStudentProfile('s1'),
            StudentCardAction.evaluate:
                '/teacher/halaqa/h1/evaluations?studentId=s1',
            StudentCardAction.contactParent: '/teacher/chat/c1',
            StudentCardAction.award: '/teacher/halaqa/h1/awards',
          };
          for (final action in actions) {
            expect(
              AppRouteAccess.isAllowed(path: paths[action]!, role: role),
              isTrue,
              reason: '$role offered $action',
            );
          }
        }
      }
    });
  });

  group('route probes', () {
    test('only teachers may open the teacher student profile and chat', () {
      expect(
        TeacherSurfaceNavigation.canOpenStudentProfile(AppRoles.teacher),
        isTrue,
      );
      expect(
        TeacherSurfaceNavigation.canOpenTeacherChat(AppRoles.teacher),
        isTrue,
      );
      for (final role in [
        AppRoles.supervisor,
        AppRoles.parent,
        AppRoles.student,
        AppRoles.admin,
        '',
      ]) {
        expect(
          TeacherSurfaceNavigation.canOpenStudentProfile(role),
          isFalse,
          reason: role,
        );
        expect(
          TeacherSurfaceNavigation.canOpenTeacherChat(role),
          isFalse,
          reason: role,
        );
      }
    });
  });
}
