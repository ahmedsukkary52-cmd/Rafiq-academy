/// أدوار المستخدمين - يتطابق مع قيمة حقل [role] في Firestore
class AppRoles {
  const AppRoles._();

  static const String student = 'student';
  static const String parent = 'parent';
  static const String teacher = 'teacher';
  static const String supervisor = 'supervisor';
  static const String admin = 'admin';

  static const List<String> all = [student, parent, teacher, supervisor, admin];
}

/// أسماء collections في Firestore
class FirestoreCollections {
  const FirestoreCollections._();

  static const String users = 'users';
  static const String studentProfiles = 'studentProfiles';
  static const String parentProfiles = 'parentProfiles';
  static const String teacherProfiles = 'teacherProfiles';
  static const String supervisorProfiles = 'supervisorProfiles';
  static const String halaqat = 'halaqat';
  static const String reviewSchedules = 'reviewSchedules';
  static const String recitationRecords = 'recitationRecords';
  static const String attendanceRecords = 'attendanceRecords';
  static const String absenceRequests = 'absenceRequests';
  static const String achievements = 'achievements';
  static const String assignments = 'assignments';
  static const String payments = 'payments';
  static const String notifications = 'notifications';
  static const String complaints = 'complaints';
  static const String supervisorReports = 'supervisorReports';
  static const String conversations = 'conversations';
  static const String messagesSubcollection = 'messages';
  static const String posts = 'posts';
  static const String commentsSubcollection = 'comments';
  static const String calendarEvents = 'calendarEvents';
  static const String contentLibrary = 'contentLibrary';
  static const String reciters = 'reciters';
  static const String surahAudios = 'surahAudios';
  static const String listeningProgress = 'listeningProgress';
}

/// أنواع التقييمات في سجل التسميع
class RecitationGrades {
  const RecitationGrades._();

  static const String excellent = 'ممتاز';
  static const String veryGood = 'جيد جداً';
  static const String good = 'جيد';
  static const String needsRetry = 'يحتاج إعادة';
}

/// أنواع الإشعارات
class NotificationTypes {
  const NotificationTypes._();

  static const String sessionReminder = 'session_reminder';
  static const String achievement = 'achievement';
  static const String payment = 'payment';
  static const String assignment = 'assignment';
  static const String attendance = 'attendance';
  static const String general = 'general';
}

/// ثوابت الـ UI العامة
class AppConstants {
  const AppConstants._();

  static const String appName = 'رفيق - أكاديمية التحفيظ';
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
}

/// Feature flags tied to infra readiness (ADR-006 / W1 D8).
///
/// Flip [audioUploadsEnabled] to `true` when Firebase Storage (Blaze) is
/// approved — homework recitation then becomes required for finish without
/// redesigning the W1 workflow.
class AppCapabilities {
  const AppCapabilities._();

  /// When false: recitation tasks are optional/deferred; no Storage uploads.
  static const bool audioUploadsEnabled = false;
}
