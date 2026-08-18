import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_permission_policy.dart';

void main() {
  group('ChatPermissionPolicy', () {
    test('teacher may chat with student, supervisor, admin', () {
      expect(
        ChatPermissionPolicy.canChat(AppRoles.teacher, AppRoles.student),
        isTrue,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.teacher, AppRoles.supervisor),
        isTrue,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.teacher, AppRoles.admin),
        isTrue,
      );
    });

    test('teacher may chat with parent', () {
      expect(
        ChatPermissionPolicy.canChat(AppRoles.teacher, AppRoles.parent),
        isTrue,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.parent, AppRoles.teacher),
        isTrue,
      );
    });

    test('student may only chat with teacher', () {
      expect(
        ChatPermissionPolicy.canChat(AppRoles.student, AppRoles.teacher),
        isTrue,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.student, AppRoles.parent),
        isFalse,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.student, AppRoles.admin),
        isFalse,
      );
    });

    test('parent may chat with teacher, supervisor and admin', () {
      expect(
        ChatPermissionPolicy.canChat(AppRoles.parent, AppRoles.teacher),
        isTrue,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.parent, AppRoles.supervisor),
        isTrue,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.parent, AppRoles.admin),
        isTrue,
      );
      expect(
        ChatPermissionPolicy.canChat(AppRoles.parent, AppRoles.student),
        isFalse,
      );
    });

    test('unknown role is denied', () {
      expect(ChatPermissionPolicy.canChat('ghost', AppRoles.teacher), isFalse);
      expect(ChatPermissionPolicy.canChat(AppRoles.teacher, 'ghost'), isFalse);
    });
  });
}
