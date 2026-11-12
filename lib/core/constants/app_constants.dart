import 'academy_branding.dart';

/// أدوار المستخدمين - يتطابق مع قيمة حقل [role] في Firestore
class AppRoles {
  const AppRoles._();

  static const String student = 'student';
  static const String parent = 'parent';
  static const String teacher = 'teacher';
  static const String supervisor = 'supervisor';
  static const String admin = 'admin';

  /// مساعد مدرس — read-only on assigned halaqat; records attendance and
  /// evaluations only while an Admin-activated cover period is active.
  static const String assistantTeacher = 'assistant_teacher';

  static const List<String> all = [
    student,
    parent,
    teacher,
    supervisor,
    admin,
    assistantTeacher,
  ];
}

/// أسماء collections في Firestore
class FirestoreCollections {
  const FirestoreCollections._();

  static const String users = 'users';
  static const String studentProfiles = 'studentProfiles';
  static const String parentProfiles = 'parentProfiles';
  static const String teacherProfiles = 'teacherProfiles';
  static const String academySettings = 'academySettings';
  static const String paymentAccess = 'paymentAccess';
  static const String auditLogs = 'auditLogs';
  static const String pricingRules = 'pricingRules';
  static const String halaqat = 'halaqat';
  static const String halaqaMeetingLinks = 'halaqaMeetingLinks';
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

  /// Threaded replies under a `halaqaActivity` assignment document.
  static const String activityResponsesSubcollection = 'activityResponses';
  static const String commentsSubcollection = 'comments';
  static const String calendarEvents = 'calendarEvents';
  static const String contentLibrary = 'contentLibrary';
  static const String reciters = 'reciters';
  static const String surahAudios = 'surahAudios';
  static const String listeningProgress = 'listeningProgress';

  /// C15 / D23 — per-student Mushaf last-read (not memorization progress).
  static const String mushafReading = 'mushafReading';

  /// C6 / WA-8 — first-class session occurrences (SSOT).
  static const String sessions = 'sessions';

  /// Append-only relationship changes (Admin read, server written).
  static const String relationshipHistory = 'relationshipHistory';

  /// Temporary cover periods per halaqa (active → completed).
  static const String halaqaCoverPeriods = 'halaqaCoverPeriods';
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
  static const String absenceRequest = 'absence_request';
  static const String complaint = 'complaint';
  static const String general = 'general';
}

/// ثوابت الـ UI العامة
class AppConstants {
  const AppConstants._();

  /// Alias of [AcademyBranding.fullTitle] — prefer branding constants in new UI.
  static const String appName = AcademyBranding.fullTitle;
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
  ///
  /// The student UI has no audio-send entry point (homework, activities,
  /// Mushaf). Flipping this to true requires adding one back, otherwise
  /// recitation tasks become required with no way to complete them.
  static const bool audioUploadsEnabled = false;

  /// D11 memorization progress (`overallProgressPercent`, verses, surahs,
  /// current plan) has no writer: the Wave C projector is blocked on the
  /// undecided `versesRange` source (OA-19 / OA-75). While false, surfaces
  /// must not present these fields as real values.
  static const bool memorizationProgressAvailable = false;

  /// `streakDays` / `level` have no writer and no design (E-12 quarantine);
  /// `points` is quarantined (P0 §3).
  static const bool streakAndLevelAvailable = false;

  /// `reviewSchedules` has no writer (OA-20); the page could only ever be
  /// empty.
  static const bool reviewSchedulesAvailable = false;
}
