import 'package:equatable/equatable.dart';

abstract class StudentEvent extends Equatable {
  const StudentEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل بروفايل الطالب (الاسم، الخطة، نسبة الإنجاز، النجوم)
class LoadStudentProfileEvent extends StudentEvent {
  final String uid;

  const LoadStudentProfileEvent(this.uid);

  @override
  List<Object?> get props => [uid];
}

/// تحميل جدول المراجعة لشهر معيّن
class LoadMonthlyReviewScheduleEvent extends StudentEvent {
  final String studentId;
  final DateTime month;

  const LoadMonthlyReviewScheduleEvent({
    required this.studentId,
    required this.month,
  });

  @override
  List<Object?> get props => [studentId, month];
}

/// تحميل سجل التسميع والتقييمات
class LoadRecitationRecordsEvent extends StudentEvent {
  final String studentId;

  const LoadRecitationRecordsEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

/// تحميل صندوق التميز (النجوم والأوسمة)
class LoadAchievementsEvent extends StudentEvent {
  final String studentId;

  const LoadAchievementsEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

/// تحميل بيانات حلقة الطالب (الموعد ورابط الزوم)
class LoadStudentHalaqaEvent extends StudentEvent {
  final String halaqaId;

  const LoadStudentHalaqaEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

/// بدء مراقبة التكليف الأخير real-time (Stream)
/// يُستدعى مرة واحدة عند فتح نافذة الطالب
class StartWatchingAssignmentEvent extends StudentEvent {
  final String studentId;

  const StartWatchingAssignmentEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

/// إعادة تحميل كل بيانات النافذة دفعة واحدة (Pull-to-refresh)
class RefreshStudentDashboardEvent extends StudentEvent {
  final String studentId;

  const RefreshStudentDashboardEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

/// Clear projection on logout so the next identity cannot inherit state (H1).
class ClearStudentSessionEvent extends StudentEvent {
  const ClearStudentSessionEvent();
}

/// اختيار/فتح شخصية (avatar) جديدة من متجر الشخصيات
class UpdateAvatarSelectionEvent extends StudentEvent {
  final String studentId;
  final String avatarId;
  final List<String> unlockedAvatarIds;
  final int coins;

  const UpdateAvatarSelectionEvent({
    required this.studentId,
    required this.avatarId,
    required this.unlockedAvatarIds,
    required this.coins,
  });

  @override
  List<Object?> get props => [studentId, avatarId, unlockedAvatarIds, coins];
}
