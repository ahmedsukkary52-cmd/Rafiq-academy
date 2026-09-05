import '../../../core/constants/app_constants.dart';

/// Client-side validation for admin ops broadcast compose form.
class AdminBroadcastFormValidation {
  const AdminBroadcastFormValidation._();

  static const allowedTargetRoles = [
    'all',
    AppRoles.parent,
    AppRoles.student,
    AppRoles.teacher,
    AppRoles.supervisor,
  ];

  static const roleLabels = {
    'all': 'الأكاديمية بالكامل',
    AppRoles.parent: 'أولياء الأمور',
    AppRoles.student: 'الطلاب',
    AppRoles.teacher: 'المعلمون',
    AppRoles.supervisor: 'المشرفون',
  };

  static String? error({
    required String title,
    required String body,
    required String targetRole,
  }) {
    if (title.trim().isEmpty) return 'أدخل عنوان الإشعار';
    if (body.trim().isEmpty) return 'أدخل نص الرسالة';
    if (!allowedTargetRoles.contains(targetRole.trim())) {
      return 'اختر فئة المستلمين';
    }
    return null;
  }
}
