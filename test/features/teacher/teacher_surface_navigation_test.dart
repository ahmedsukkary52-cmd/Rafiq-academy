import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/teacher/presentation/teacher_contact_parent.dart';
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

    test('supervisor is offered parent contact, not profile, when at risk', () {
      final actions = TeacherSurfaceNavigation.studentCardActions(
        role: AppRoles.supervisor,
        isAtRisk: true,
      );
      expect(actions, [
        StudentCardAction.evaluate,
        StudentCardAction.contactParent,
      ]);
    });

    test('non-staff viewers are never offered parent contact', () {
      for (final role in [AppRoles.parent, AppRoles.student, '']) {
        expect(
          TeacherSurfaceNavigation.studentCardActions(
            role: role,
            isAtRisk: true,
          ),
          isNot(contains(StudentCardAction.contactParent)),
          reason: role,
        );
      }
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
            StudentCardAction.contactParent: staffParentChatRoute(role, 'c1'),
            StudentCardAction.award: '/teacher/halaqa/h1/awards',
          };
          for (final action in actions) {
            final path = paths[action];
            if (path == null) {
              // Supervisor parent chat opens in-feature, not via the router.
              expect(action, StudentCardAction.contactParent);
              expect(role, AppRoles.supervisor);
              continue;
            }
            expect(
              AppRouteAccess.isAllowed(path: path, role: role),
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
