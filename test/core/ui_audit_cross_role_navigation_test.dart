import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/router/router_app.dart';
import 'package:rafiq_academy/features/student/domain/student_profile_content.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_profile_page.dart';
import 'package:rafiq_academy/features/teacher/presentation/teacher_contact_parent.dart';

void main() {
  group('student profile "contact parent" opens a chat the role may reach', () {
    test('teacher and admin get their own chat route', () {
      expect(staffParentChatRoute(AppRoles.teacher, 'c1'), '/teacher/chat/c1');
      expect(staffParentChatRoute(AppRoles.admin, 'c1'), '/admin/chat/c1');
    });

    test('every returned route passes the router access check', () {
      for (final role in [AppRoles.teacher, AppRoles.admin]) {
        final route = staffParentChatRoute(role, 'c1')!;
        expect(
          AppRouteAccess.isAllowed(path: route, role: role),
          isTrue,
          reason: role,
        );
      }
    });

    test('supervisor has no chat route and opens the room in-feature', () {
      expect(staffParentChatRoute(AppRoles.supervisor, 'c1'), isNull);
      expect(
        AppRouteAccess.isAllowed(
          path: '/teacher/chat/c1',
          role: AppRoles.supervisor,
        ),
        isFalse,
      );
    });

    test('only staff roles are offered the action', () {
      expect(staffCanContactStudentParent(AppRoles.teacher), isTrue);
      expect(staffCanContactStudentParent(AppRoles.supervisor), isTrue);
      expect(staffCanContactStudentParent(AppRoles.admin), isTrue);
      expect(staffCanContactStudentParent(AppRoles.parent), isFalse);
      expect(staffCanContactStudentParent(AppRoles.student), isFalse);
    });
  });

  group('student profile "evaluations" link matches router access', () {
    final path = studentProfileEvaluationsPath(halaqaId: 'h1', studentId: 's1')!;

    for (final role in [
      AppRoles.teacher,
      AppRoles.supervisor,
      AppRoles.admin,
    ]) {
      test(role, () {
        expect(
          staffCanOpenStudentEvaluations(role),
          AppRouteAccess.isAllowed(path: path, role: role),
        );
      });
    }

    test('admin is not offered a link the router would bounce', () {
      expect(staffCanOpenStudentEvaluations(AppRoles.admin), isFalse);
    });
  });
}
