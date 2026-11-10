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

  /// Who reads a role/`all` notification (`audience in [uid, role, 'all']`).
  static String audienceExplanation(String targetRole) => switch (targetRole) {
    'all' =>
      'يصل إلى كل حسابات الأكاديمية: الطلاب وأولياء الأمور والمعلمين '
          'والمشرفين والإدارة.',
    AppRoles.parent => 'يصل إلى حسابات أولياء الأمور فقط.',
    AppRoles.student => 'يصل إلى حسابات الطلاب فقط.',
    AppRoles.teacher => 'يصل إلى حسابات المعلمين فقط.',
    AppRoles.supervisor => 'يصل إلى حسابات المشرفين فقط.',
    _ => 'اختر فئة المستلمين',
  };

  static const deliveryNote =
      'يظهر داخل التطبيق في صفحة الإشعارات لكل حساب من هذه الفئة، '
      'بما في ذلك الحسابات التي تُضاف لاحقًا. لا يُرسل إشعار فوري (Push) حاليًا.';

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
