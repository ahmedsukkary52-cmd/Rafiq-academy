import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/router/app_routes.dart';
import 'package:rafiq_academy/features/staff/contact_parent/contact_student_parent.dart';
import 'package:rafiq_academy/features/staff/student_profile/domain/student_profile_content.dart';
import 'package:rafiq_academy/features/staff/student_profile/presentation/student_profile_viewer.dart';

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

    for (final viewer in StudentProfileViewer.values) {
      test(viewer.role, () {
        expect(
          viewer.canOpenEvaluations,
          AppRouteAccess.isAllowed(path: path, role: viewer.role),
        );
      });
    }

    test('admin is not offered a link the router would bounce', () {
      expect(StudentProfileViewer.admin.canOpenEvaluations, isFalse);
    });
  });
}
