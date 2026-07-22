import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/usecases/get_achievements_usecase.dart';
import '../../domain/usecases/get_monthly_review_schedule_usecase.dart';
import '../../domain/usecases/get_recitation_records_usecase.dart';
import '../../domain/usecases/get_student_halaqa_usecase.dart';
import '../../domain/usecases/get_student_profile_usecase.dart';
import '../../domain/usecases/update_avatar_selection_usecase.dart';
import '../../domain/usecases/watch_latest_assignment_usecase.dart';
import 'student_event.dart';
import 'student_state.dart';

/// @singleton لأن نافذة الطالب متوقع تتبني بنمط Tabs/IndexedStack
/// (بروفايل، جدول، تسميع، إنجازات كلهم تابات في نفس النافذة)
/// فلازم الـ Bloc يفضل واحد طول ما الطالب جوه نافذته، عشان التنقل
/// بين التابات ميعملش إعادة تحميل من الصفر كل مرة.
@singleton
class StudentBloc extends Bloc<StudentEvent, StudentState> {
  final GetStudentProfileUseCase getStudentProfile;
  final GetMonthlyReviewScheduleUseCase getMonthlyReviewSchedule;
  final GetRecitationRecordsUseCase getRecitationRecords;
  final GetAchievementsUseCase getAchievements;
  final GetStudentHalaqaUseCase getStudentHalaqa;
  final WatchLatestAssignmentUseCase watchLatestAssignment;
  final UpdateAvatarSelectionUseCase updateAvatarSelection;

  StudentBloc({
    required this.getStudentProfile,
    required this.getMonthlyReviewSchedule,
    required this.getRecitationRecords,
    required this.getAchievements,
    required this.getStudentHalaqa,
    required this.watchLatestAssignment,
    required this.updateAvatarSelection,
  }) : super(StudentState.initial()) {
    on<LoadStudentProfileEvent>(_onLoadProfile);
    on<LoadMonthlyReviewScheduleEvent>(_onLoadMonthlySchedule);
    on<LoadRecitationRecordsEvent>(_onLoadRecitationRecords);
    on<LoadAchievementsEvent>(_onLoadAchievements);
    on<LoadStudentHalaqaEvent>(_onLoadHalaqa);
    on<StartWatchingAssignmentEvent>(
      _onStartWatchingAssignment,
      // restartable: لو الـ event اتبعت تاني وفيه subscription شغال،
      // يلغي القديم ويبدأ الجديد بدل ما يفضل عندنا أكتر من listener
      // على نفس الـ Stream في نفس الوقت.
      transformer: restartable(),
    );
    on<RefreshStudentDashboardEvent>(_onRefreshDashboard);
    on<UpdateAvatarSelectionEvent>(_onUpdateAvatarSelection);
  }

  // ══════════════════════════════════════════════════════════════════════
  // البروفايل
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadProfile(
    LoadStudentProfileEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(
      state.copyWith(profileStatus: SectionStatus.loading, profileError: null),
    );

    final result = await getStudentProfile(StudentUidParams(event.uid));

    result.fold(
      (failure) => emit(
        state.copyWith(
          profileStatus: SectionStatus.error,
          profileError: failure.message,
        ),
      ),
      (profile) => emit(
        state.copyWith(profileStatus: SectionStatus.loaded, profile: profile),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // جدول المراجعة الشهري
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadMonthlySchedule(
    LoadMonthlyReviewScheduleEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(
      state.copyWith(
        scheduleStatus: SectionStatus.loading,
        scheduleError: null,
      ),
    );

    final result = await getMonthlyReviewSchedule(
      MonthlyScheduleParams(studentId: event.studentId, month: event.month),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          scheduleStatus: SectionStatus.error,
          scheduleError: failure.message,
        ),
      ),
      (schedule) => emit(
        state.copyWith(
          scheduleStatus: SectionStatus.loaded,
          reviewSchedule: schedule,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // سجل التسميع والتقييمات
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadRecitationRecords(
    LoadRecitationRecordsEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(
      state.copyWith(
        recitationStatus: SectionStatus.loading,
        recitationError: null,
      ),
    );

    final result = await getRecitationRecords(
      StudentUidParams(event.studentId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          recitationStatus: SectionStatus.error,
          recitationError: failure.message,
        ),
      ),
      (records) => emit(
        state.copyWith(
          recitationStatus: SectionStatus.loaded,
          recitationRecords: records,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // صندوق التميز
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadAchievements(
    LoadAchievementsEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(
      state.copyWith(
        achievementsStatus: SectionStatus.loading,
        achievementsError: null,
      ),
    );

    final result = await getAchievements(StudentUidParams(event.studentId));

    result.fold(
      (failure) => emit(
        state.copyWith(
          achievementsStatus: SectionStatus.error,
          achievementsError: failure.message,
        ),
      ),
      (achievements) => emit(
        state.copyWith(
          achievementsStatus: SectionStatus.loaded,
          achievements: achievements,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // الحلقة
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onLoadHalaqa(
    LoadStudentHalaqaEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(
      state.copyWith(halaqaStatus: SectionStatus.loading, halaqaError: null),
    );

    final result = await getStudentHalaqa(HalaqaIdParams(event.halaqaId));

    result.fold(
      (failure) => emit(
        state.copyWith(
          halaqaStatus: SectionStatus.error,
          halaqaError: failure.message,
        ),
      ),
      (halaqa) => emit(
        state.copyWith(halaqaStatus: SectionStatus.loaded, halaqa: halaqa),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // التكليف الأخير - Stream (real-time)
  // ══════════════════════════════════════════════════════════════════════

  /// بنبدأ نسمع للـ Stream عن طريق [Emitter.forEach] اللي بيدير الـ
  /// subscription بشكل تلقائي وآمن: بيتقفل لوحده لو الـ Bloc اتقفل،
  /// أو لو event تاني من نفس النوع وصل (حسب الـ event transformer).
  /// مفيش داعي نمسك StreamSubscription يدوي هنا.
  Future<void> _onStartWatchingAssignment(
    StartWatchingAssignmentEvent event,
    Emitter<StudentState> emit,
  ) async {
    await emit.forEach(
      watchLatestAssignment(StudentUidParams(event.studentId)),
      onData: (either) => either.fold(
        (failure) => state,
        // لو فشل الـ stream نتجاهل ونحافظ على آخر حالة معروفة
        (assignment) => state.copyWith(latestAssignment: assignment),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // إعادة تحميل كل شيء (Pull-to-refresh)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onRefreshDashboard(
    RefreshStudentDashboardEvent event,
    Emitter<StudentState> emit,
  ) async {
    // بنشغّل كل الطلبات بالتوازي بدل التتابع، عشان يبقى أسرع.
    // مش بنستخدم Future.wait مباشرة لأن كل واحد منهم لازم يـ emit
    // بشكل مستقل لحاله، فبنستدعيهم مع بعض من غير await منفرد.
    await Future.wait([
      _onLoadProfile(LoadStudentProfileEvent(event.studentId), emit),
      _onLoadRecitationRecords(
        LoadRecitationRecordsEvent(event.studentId),
        emit,
      ),
      _onLoadMonthlySchedule(
        LoadMonthlyReviewScheduleEvent(
          studentId: event.studentId,
          month: DateTime.now(),
        ),
        emit,
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════
  // اختيار/فتح شخصية (avatar)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onUpdateAvatarSelection(
    UpdateAvatarSelectionEvent event,
    Emitter<StudentState> emit,
  ) async {
    emit(
      state.copyWith(
        avatarUpdateStatus: SectionStatus.loading,
        avatarUpdateError: null,
      ),
    );

    final result = await updateAvatarSelection(
      UpdateAvatarSelectionParams(
        studentId: event.studentId,
        avatarId: event.avatarId,
        unlockedAvatarIds: event.unlockedAvatarIds,
        coins: event.coins,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          avatarUpdateStatus: SectionStatus.error,
          avatarUpdateError: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(avatarUpdateStatus: SectionStatus.loaded));
        // نحدّث الـ profile محليًا فورًا بدل ما نستنى إعادة تحميل من Firestore
        final current = state.profile;
        if (current != null) {
          emit(
            state.copyWith(
              profile: current.copyWith(
                avatarId: event.avatarId,
                unlockedAvatarIds: event.unlockedAvatarIds,
                coins: event.coins,
              ),
            ),
          );
        }
      },
    );
  }
}
