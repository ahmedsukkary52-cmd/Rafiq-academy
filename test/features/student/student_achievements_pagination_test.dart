import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
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
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/domain/id_params.dart';

typedef _E<T> = Either<Failure, T>;

AchievementEntity _a(String id, DateTime date) => AchievementEntity(
  id: id,
  studentId: 's1',
  type: AchievementType.star,
  title: id,
  issuedBy: 't1',
  date: date,
);

class _Achievements extends Fake implements GetAchievementsUseCase {
  final fullCalls = <String>[];
  final pageCalls = <(String, String?, String?)>[];
  final pages = <String?, StudentAchievementsPage>{};
  List<AchievementEntity> full = const [];

  @override
  Future<_E<List<AchievementEntity>>> call(StudentUidParams params) async {
    fullCalls.add(params.uid);
    return Right(full);
  }

  @override
  Future<_E<StudentAchievementsPage>> page({
    required String studentId,
    int limit = StudentAchievementsPage.defaultLimit,
    String? afterStudentAchievementId,
    String? afterRecipientsAchievementId,
  }) async {
    pageCalls.add((
      studentId,
      afterStudentAchievementId,
      afterRecipientsAchievementId,
    ));
    return Right(
      pages[afterStudentAchievementId] ??
          const StudentAchievementsPage(
            items: [],
            studentCursorId: null,
            recipientsCursorId: null,
            hasMoreStudent: false,
            hasMoreRecipients: false,
          ),
    );
  }
}

StudentBloc _bloc(_Achievements achievements) => StudentBloc(
  getStudentProfile: _UnusedProfile(),
  getMonthlyReviewSchedule: _UnusedSchedule(),
  getRecitationRecords: _UnusedRecitations(),
  getAchievements: achievements,
  getStudentHalaqa: _UnusedHalaqa(),
  watchLatestAssignment: _UnusedWatch(),
  updateAvatarSelection: _UnusedAvatar(),
);

class _UnusedProfile extends Fake implements GetStudentProfileUseCase {}

class _UnusedSchedule extends Fake implements GetMonthlyReviewScheduleUseCase {}

class _UnusedRecitations extends Fake implements GetRecitationRecordsUseCase {}

class _UnusedHalaqa extends Fake implements GetStudentHalaqaUseCase {}

class _UnusedWatch extends Fake implements WatchLatestAssignmentUseCase {}

class _UnusedAvatar extends Fake implements UpdateAvatarSelectionUseCase {}

void main() {
  test('paged load uses page API; LoadMore appends without duplicates', () async {
    final achievements = _Achievements();
    final bloc = _bloc(achievements);
    addTearDown(bloc.close);

    achievements.pages[null] = StudentAchievementsPage(
      items: [_a('a2', DateTime(2026, 2, 1)), _a('a1', DateTime(2026, 1, 1))],
      studentCursorId: 'a1',
      recipientsCursorId: 'r1',
      hasMoreStudent: true,
      hasMoreRecipients: false,
    );
    achievements.pages['a1'] = StudentAchievementsPage(
      items: [_a('a0', DateTime(2025, 12, 1)), _a('a1', DateTime(2026, 1, 1))],
      studentCursorId: 'a0',
      recipientsCursorId: 'r1',
      hasMoreStudent: false,
      hasMoreRecipients: false,
    );

    bloc.add(const LoadAchievementsEvent('s1', paged: true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(achievements.fullCalls, isEmpty);
    expect(bloc.state.achievements.map((a) => a.id), ['a2', 'a1']);
    expect(bloc.state.achievementsHasMore, isTrue);

    bloc.add(const LoadMoreAchievementsEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(achievements.pageCalls.last.$2, 'a1');
    expect(bloc.state.achievements.map((a) => a.id), ['a2', 'a1', 'a0']);
    expect(bloc.state.achievementsHasMore, isFalse);
  });

  test('non-paged load uses full getAchievements (badges path)', () async {
    final achievements = _Achievements();
    achievements.full = [_a('all', DateTime(2026, 1, 1))];
    final bloc = _bloc(achievements);
    addTearDown(bloc.close);

    bloc.add(const LoadAchievementsEvent('s1'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(achievements.fullCalls, ['s1']);
    expect(achievements.pageCalls, isEmpty);
    expect(bloc.state.achievementsStatus, SectionStatus.loaded);
    expect(bloc.state.achievementsHasMore, isFalse);
  });
}
