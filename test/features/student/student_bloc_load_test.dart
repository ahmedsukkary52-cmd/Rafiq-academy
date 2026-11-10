import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/domain/assignment_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/review_schedule_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_achievements_usecase.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_monthly_review_schedule_usecase.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_recitation_records_usecase.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_student_halaqa_usecase.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_student_profile_usecase.dart';
import 'package:rafiq_academy/features/student/domain/usecases/update_avatar_selection_usecase.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_bloc.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_event.dart';
import 'package:rafiq_academy/features/student/presentation/bloc/student_state.dart';

StudentProfileEntity _profile() => const StudentProfileEntity(
  uid: 's1',
  name: 'أحمد',
  currentPlanName: 'جزء عم',
  overallProgressPercent: 40,
  totalStars: 10,
  badges: [],
  halaqaId: 'h1',
  streakDays: 3,
  completedSurahs: 2,
);

class _FakeStudentRepository implements StudentRepository {
  Either<Failure, StudentProfileEntity> profileResult = Right(_profile());
  Either<Failure, List<RecitationRecordEntity>> recitationsResult = const Right(
    [],
  );
  Either<Failure, List<AchievementEntity>> achievementsResult = const Right([]);

  @override
  Future<Either<Failure, StudentProfileEntity>> getStudentProfile(
    String uid,
  ) async => profileResult;

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  ) async => recitationsResult;

  @override
  Future<Either<Failure, List<AchievementEntity>>> getAchievements(
    String studentId,
  ) async => achievementsResult;

  @override
  Future<Either<Failure, HalaqaEntity>> getStudentHalaqa(
    String halaqaId,
  ) async => Right(
    HalaqaEntity(
      id: halaqaId,
      name: 'حلقة',
      teacherId: 't1',
      supervisorId: 'sup1',
      studentIds: const ['s1'],
      schedule: const [],
      status: 'active',
    ),
  );

  @override
  Future<Either<Failure, List<ReviewScheduleEntity>>> getMonthlyReviewSchedule({
    required String studentId,
    required DateTime month,
  }) async => const Right([]);

  @override
  Future<Either<Failure, AssignmentEntity?>> getLatestAssignment(
    String studentId,
  ) async => const Right(null);

  @override
  Stream<Either<Failure, AssignmentEntity?>> watchLatestAssignment(
    String studentId,
  ) => Stream.value(const Right(null));

  @override
  Future<Either<Failure, Unit>> updateAvatarSelection({
    required String studentId,
    required String avatarId,
    required List<String> unlockedAvatarIds,
    required int coins,
  }) async => const Right(unit);
}

StudentBloc _buildBloc(_FakeStudentRepository repo) {
  return StudentBloc(
    getStudentProfile: GetStudentProfileUseCase(repo),
    getMonthlyReviewSchedule: GetMonthlyReviewScheduleUseCase(repo),
    getRecitationRecords: GetRecitationRecordsUseCase(repo),
    getAchievements: GetAchievementsUseCase(repo),
    getStudentHalaqa: GetStudentHalaqaUseCase(repo),
    watchLatestAssignment: WatchLatestAssignmentUseCase(repo),
    updateAvatarSelection: UpdateAvatarSelectionUseCase(repo),
  );
}

void main() {
  group('StudentBloc', () {
    test('loads profile into loaded state', () async {
      final bloc = _buildBloc(_FakeStudentRepository());
      bloc.add(const LoadStudentProfileEvent('s1'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<StudentState>()
              .having((s) => s.profileStatus, 'status', SectionStatus.loaded)
              .having((s) => s.profile?.uid, 'uid', 's1'),
        ),
      );
      await bloc.close();
    });

    test('surfaces profile failure', () async {
      final repo = _FakeStudentRepository()
        ..profileResult = const Left(ServerFailure('offline'));
      final bloc = _buildBloc(repo);
      bloc.add(const LoadStudentProfileEvent('s1'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<StudentState>()
              .having((s) => s.profileStatus, 'status', SectionStatus.error)
              .having((s) => s.profileError, 'error', 'offline'),
        ),
      );
      await bloc.close();
    });

    test('clear session resets state', () async {
      final bloc = _buildBloc(_FakeStudentRepository());
      bloc.add(const LoadStudentProfileEvent('s1'));
      await bloc.stream.firstWhere(
        (s) => s.profileStatus == SectionStatus.loaded,
      );
      bloc.add(const ClearStudentSessionEvent());
      await expectLater(
        bloc.stream,
        emits(
          isA<StudentState>().having(
            (s) => s.profileStatus,
            'status',
            SectionStatus.initial,
          ),
        ),
      );
      await bloc.close();
    });

    test('loads achievements empty list as loaded', () async {
      final bloc = _buildBloc(_FakeStudentRepository());
      bloc.add(const LoadAchievementsEvent('s1'));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<StudentState>()
              .having(
                (s) => s.achievementsStatus,
                'status',
                SectionStatus.loaded,
              )
              .having((s) => s.achievements, 'list', isEmpty),
        ),
      );
      await bloc.close();
    });
  });
}
