import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/achievement_entity.dart';
import '../../domain/entities/assignment_entity.dart';
import '../../domain/entities/halaqa_entity.dart';
import '../../domain/entities/recitation_record_entity.dart';
import '../../domain/entities/review_schedule_entity.dart';
import '../../domain/entities/student_profile_entity.dart';

/// Sentinel خاص يُستخدم في [StudentState.copyWith] للتفريق بين:
/// - "الباراميتر ده مش متبعوت خالص" → نحافظ على القيمة القديمة
/// - "الباراميتر ده اتبعت بقيمة null صراحة" → نمسح القيمة فعلاً
///
/// لو استخدمنا `param ?? this.param` العادية، مش هينفع نمسح حاجة
/// (زي رسالة error بعد ما تتحل) لأن أي استدعاء من غير الباراميتر ده
/// هيرجعها null تلقائي، وده bug بيصعب اكتشافه بعدين.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

class StudentState extends Equatable {
  // ── البروفايل ──────────────────────────────────────────────────────────
  final SectionStatus profileStatus;
  final StudentProfileEntity? profile;
  final String? profileError;

  // ── جدول المراجعة الشهري ──────────────────────────────────────────────
  final SectionStatus scheduleStatus;
  final List<ReviewScheduleEntity> reviewSchedule;
  final String? scheduleError;

  // ── سجل التسميع والتقييمات ────────────────────────────────────────────
  final SectionStatus recitationStatus;
  final List<RecitationRecordEntity> recitationRecords;
  final String? recitationError;

  // ── صندوق التميز ──────────────────────────────────────────────────────
  final SectionStatus achievementsStatus;
  final List<AchievementEntity> achievements;
  final String? achievementsError;

  // ── الحلقة (الموعد ورابط الزوم) ───────────────────────────────────────
  final SectionStatus halaqaStatus;
  final HalaqaEntity? halaqa;
  final String? halaqaError;

  // ── التكليف الأخير (يتحدّث real-time عن طريق Stream) ───────────────────
  final AssignmentEntity? latestAssignment;

  // ── تحديث اختيار الشخصية (avatar) ──────────────────────────────────────
  final SectionStatus avatarUpdateStatus;
  final String? avatarUpdateError;

  const StudentState({
    this.profileStatus = SectionStatus.initial,
    this.profile,
    this.profileError,
    this.scheduleStatus = SectionStatus.initial,
    this.reviewSchedule = const [],
    this.scheduleError,
    this.recitationStatus = SectionStatus.initial,
    this.recitationRecords = const [],
    this.recitationError,
    this.achievementsStatus = SectionStatus.initial,
    this.achievements = const [],
    this.achievementsError,
    this.halaqaStatus = SectionStatus.initial,
    this.halaqa,
    this.halaqaError,
    this.latestAssignment,
    this.avatarUpdateStatus = SectionStatus.initial,
    this.avatarUpdateError,
  });

  /// الحالة الابتدائية عند فتح نافذة الطالب لأول مرة
  factory StudentState.initial() => const StudentState();

  /// كل باراميتر هنا نوعه [Object?] وقيمته الافتراضية [_unset]،
  /// مش القيمة الحقيقية بتاعته. ده يخلينا نفرّق بدقة بين "متبعوتش"
  /// و"اتبعت null صراحة" - مهم جداً لحقول الـ error والـ nullable entities.
  StudentState copyWith({
    SectionStatus? profileStatus,
    Object? profile = _unset,
    Object? profileError = _unset,
    SectionStatus? scheduleStatus,
    List<ReviewScheduleEntity>? reviewSchedule,
    Object? scheduleError = _unset,
    SectionStatus? recitationStatus,
    List<RecitationRecordEntity>? recitationRecords,
    Object? recitationError = _unset,
    SectionStatus? achievementsStatus,
    List<AchievementEntity>? achievements,
    Object? achievementsError = _unset,
    SectionStatus? halaqaStatus,
    Object? halaqa = _unset,
    Object? halaqaError = _unset,
    Object? latestAssignment = _unset,
    SectionStatus? avatarUpdateStatus,
    Object? avatarUpdateError = _unset,
  }) {
    return StudentState(
      profileStatus: profileStatus ?? this.profileStatus,
      profile: identical(profile, _unset)
          ? this.profile
          : profile as StudentProfileEntity?,
      profileError: identical(profileError, _unset)
          ? this.profileError
          : profileError as String?,
      scheduleStatus: scheduleStatus ?? this.scheduleStatus,
      reviewSchedule: reviewSchedule ?? this.reviewSchedule,
      scheduleError: identical(scheduleError, _unset)
          ? this.scheduleError
          : scheduleError as String?,
      recitationStatus: recitationStatus ?? this.recitationStatus,
      recitationRecords: recitationRecords ?? this.recitationRecords,
      recitationError: identical(recitationError, _unset)
          ? this.recitationError
          : recitationError as String?,
      achievementsStatus: achievementsStatus ?? this.achievementsStatus,
      achievements: achievements ?? this.achievements,
      achievementsError: identical(achievementsError, _unset)
          ? this.achievementsError
          : achievementsError as String?,
      halaqaStatus: halaqaStatus ?? this.halaqaStatus,
      halaqa: identical(halaqa, _unset) ? this.halaqa : halaqa as HalaqaEntity?,
      halaqaError: identical(halaqaError, _unset)
          ? this.halaqaError
          : halaqaError as String?,
      latestAssignment: identical(latestAssignment, _unset)
          ? this.latestAssignment
          : latestAssignment as AssignmentEntity?,
      avatarUpdateStatus: avatarUpdateStatus ?? this.avatarUpdateStatus,
      avatarUpdateError: identical(avatarUpdateError, _unset)
          ? this.avatarUpdateError
          : avatarUpdateError as String?,
    );
  }

  @override
  List<Object?> get props => [
    profileStatus,
    profile,
    profileError,
    scheduleStatus,
    reviewSchedule,
    scheduleError,
    recitationStatus,
    recitationRecords,
    recitationError,
    achievementsStatus,
    achievements,
    achievementsError,
    halaqaStatus,
    halaqa,
    halaqaError,
    latestAssignment,
    avatarUpdateStatus,
    avatarUpdateError,
  ];
}
