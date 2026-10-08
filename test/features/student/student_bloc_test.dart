import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/student/domain/entities/achievement_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/assignment_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
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

const _profile = StudentProfileEntity(
  uid: 's1',
  name: 'أحمد',
  currentPlanName: '',
  overallProgressPercent: 0,
  totalStars: 0,
  badges: [],
);

final _assignment = AssignmentEntity(
  id: 'a1',
  studentId: 's1',
  assignedBy: 't1',
  newMemorizationRange: 'الملك 1-5',
  reviewRange: '',
  dueDate: DateTime(2026, 9, 10),
);

class _FakeStudentRepository extends Fake implements StudentRepository {
  Either<Failure, StudentProfileEntity> profile = const Right(_profile);
  Either<Failure, List<RecitationRecordEntity>> records = const Right([]);
  Either<Failure, List<ReviewScheduleEntity>> schedule = const Right([]);
  Either<Failure, List<AchievementEntity>> achievements = const Right([]);
  Either<Failure, HalaqaEntity>? halaqa;
  Either<Failure, Unit> avatar = const Right(unit);

  final calls = <String>[];
  final assignmentStreams = <StreamController<Either<Failure, AssignmentEntity?>>>[];

  StreamController<Either<Failure, AssignmentEntity?>> get latestStream =>
      assignmentStreams.last;

  @override
  Future<Either<Failure, StudentProfileEntity>> getStudentProfile(
    String uid,
  ) async {
    calls.add('profile:$uid');
    return profile;
  }

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  ) async {
    calls.add('records:$studentId');
    return records;
  }

  @override
  Future<Either<Failure, List<ReviewScheduleEntity>>> getMonthlyReviewSchedule({
    required String studentId,
    required DateTime month,
  }) async {
    calls.add('schedule:$studentId');
    return schedule;
  }

  @override
  Future<Either<Failure, List<AchievementEntity>>> getAchievements(
    String studentId,
  ) async {
    calls.add('achievements:$studentId');
    return achievements;
  }

  @override
  Future<Either<Failure, HalaqaEntity>> getStudentHalaqa(String halaqaId) async {
    calls.add('halaqa:$halaqaId');
    return halaqa!;
  }

  @override
  Stream<Either<Failure, AssignmentEntity?>> watchLatestAssignment(
    String studentId,
  ) {
    calls.add('watch:$studentId');
    final controller = StreamController<Either<Failure, AssignmentEntity?>>();
    assignmentStreams.add(controller);
    return controller.stream;
  }

  @override
  Future<Either<Failure, Unit>> updateAvatarSelection({
    required String studentId,
    required String avatarId,
    required List<String> unlockedAvatarIds,
    required int coins,
  }) async {
    calls.add('avatar:$studentId:$avatarId:$coins');
    return avatar;
  }
}

StudentBloc _bloc(StudentRepository repo) => StudentBloc(
  getStudentProfile: GetStudentProfileUseCase(repo),
  getMonthlyReviewSchedule: GetMonthlyReviewScheduleUseCase(repo),
  getRecitationRecords: GetRecitationRecordsUseCase(repo),
  getAchievements: GetAchievementsUseCase(repo),
  getStudentHalaqa: GetStudentHalaqaUseCase(repo),
  watchLatestAssignment: WatchLatestAssignmentUseCase(repo),
  updateAvatarSelection: UpdateAvatarSelectionUseCase(repo),
);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _FakeStudentRepository repo;
  late StudentBloc bloc;

  setUp(() {
    repo = _FakeStudentRepository();
    bloc = _bloc(repo);
  });

  tearDown(() => bloc.close());

  test('initial state has every section idle', () {
    expect(bloc.state, StudentState.initial());
    expect(bloc.state.profileStatus, SectionStatus.initial);
    expect(bloc.state.latestAssignmentStatus, SectionStatus.initial);
  });

  group('profile', () {
    test('loading then loaded', () async {
      final seen = <SectionStatus>[];
      final sub = bloc.stream.listen((s) => seen.add(s.profileStatus));

      bloc.add(const LoadStudentProfileEvent('s1'));
      await _settle();
      await sub.cancel();

      expect(seen, [SectionStatus.loading, SectionStatus.loaded]);
      expect(bloc.state.profile, _profile);
      expect(repo.calls, ['profile:s1']);
    });

    test('failure keeps the message; retry clears it', () async {
      repo.profile = const Left(ServerFailure('تعذر التحميل'));
      bloc.add(const LoadStudentProfileEvent('s1'));
      await _settle();
      expect(bloc.state.profileStatus, SectionStatus.error);
      expect(bloc.state.profileError, 'تعذر التحميل');
      expect(bloc.state.profile, isNull);

      repo.profile = const Right(_profile);
      bloc.add(const LoadStudentProfileEvent('s1'));
      await _settle();
      expect(bloc.state.profileStatus, SectionStatus.loaded);
      expect(bloc.state.profileError, isNull);
    });
  });

  group('lists', () {
    test('empty recitation records and achievements are loaded, not errors',
        () async {
      bloc
        ..add(const LoadRecitationRecordsEvent('s1'))
        ..add(const LoadAchievementsEvent('s1'));
      await _settle();

      expect(bloc.state.recitationStatus, SectionStatus.loaded);
      expect(bloc.state.recitationRecords, isEmpty);
      expect(bloc.state.achievementsStatus, SectionStatus.loaded);
      expect(bloc.state.achievements, isEmpty);
    });

    test('a failing section does not disturb the others', () async {
      repo.records = const Left(NetworkFailure());
      bloc
        ..add(const LoadStudentProfileEvent('s1'))
        ..add(const LoadRecitationRecordsEvent('s1'));
      await _settle();

      expect(bloc.state.profileStatus, SectionStatus.loaded);
      expect(bloc.state.recitationStatus, SectionStatus.error);
      expect(bloc.state.recitationError, const NetworkFailure().message);
    });

    test('halaqa failure is surfaced', () async {
      repo.halaqa = const Left(ServerFailure('الحلقة غير موجودة'));
      bloc.add(const LoadStudentHalaqaEvent('h1'));
      await _settle();

      expect(repo.calls, ['halaqa:h1']);
      expect(bloc.state.halaqaStatus, SectionStatus.error);
      expect(bloc.state.halaqaError, 'الحلقة غير موجودة');
    });
  });

  group('latest assignment stream', () {
    test('loading, then data, then a stream failure', () async {
      bloc.add(const StartWatchingAssignmentEvent('s1'));
      await _settle();
      expect(bloc.state.latestAssignmentStatus, SectionStatus.loading);

      repo.latestStream.add(Right(_assignment));
      await _settle();
      expect(bloc.state.latestAssignmentStatus, SectionStatus.loaded);
      expect(bloc.state.latestAssignment, _assignment);

      repo.latestStream.add(const Left(ServerFailure('انقطع الاتصال')));
      await _settle();
      expect(bloc.state.latestAssignmentStatus, SectionStatus.error);
      expect(bloc.state.latestAssignmentError, 'انقطع الاتصال');
    });

    test('no assignment yet is loaded with null', () async {
      bloc.add(const StartWatchingAssignmentEvent('s1'));
      await _settle();
      repo.latestStream.add(const Right(null));
      await _settle();

      expect(bloc.state.latestAssignmentStatus, SectionStatus.loaded);
      expect(bloc.state.latestAssignment, isNull);
    });

    test('restarting replaces the previous subscription', () async {
      bloc.add(const StartWatchingAssignmentEvent('s1'));
      await _settle();
      final first = repo.latestStream;
      bloc.add(const StartWatchingAssignmentEvent('s1'));
      await _settle();

      expect(repo.assignmentStreams, hasLength(2));
      expect(first.hasListener, isFalse);
      expect(repo.latestStream.hasListener, isTrue);
    });

    test('logout clears state and ignores late snapshots', () async {
      bloc.add(const StartWatchingAssignmentEvent('s1'));
      await _settle();
      final stream = repo.latestStream;

      bloc.add(const ClearStudentSessionEvent());
      await _settle();
      stream.add(Right(_assignment));
      await _settle();

      expect(bloc.state, StudentState.initial());
    });
  });

  test('refresh reloads sections and re-attaches the assignment watch',
      () async {
    bloc.add(const StartWatchingAssignmentEvent('s1'));
    await _settle();
    repo.latestStream.add(const Left(ServerFailure('x')));
    await _settle();
    expect(bloc.state.latestAssignmentStatus, SectionStatus.error);

    bloc.add(const RefreshStudentDashboardEvent('s1'));
    await _settle();
    repo.latestStream.add(Right(_assignment));
    await _settle();

    expect(
      repo.calls,
      containsAll(['profile:s1', 'records:s1', 'schedule:s1']),
    );
    expect(repo.calls.where((c) => c == 'watch:s1'), hasLength(2));
    expect(bloc.state.latestAssignmentStatus, SectionStatus.loaded);
  });

  group('avatar selection', () {
    test('success updates the loaded profile locally', () async {
      bloc.add(const LoadStudentProfileEvent('s1'));
      await _settle();

      bloc.add(
        const UpdateAvatarSelectionEvent(
          studentId: 's1',
          avatarId: 'owl',
          unlockedAvatarIds: ['owl'],
          coins: 5,
        ),
      );
      await _settle();

      expect(repo.calls.last, 'avatar:s1:owl:5');
      expect(bloc.state.avatarUpdateStatus, SectionStatus.loaded);
      expect(bloc.state.profile!.avatarId, 'owl');
      expect(bloc.state.profile!.coins, 5);
    });

    test('failure leaves the profile unchanged', () async {
      bloc.add(const LoadStudentProfileEvent('s1'));
      await _settle();
      repo.avatar = const Left(ServerFailure('رصيد غير كافٍ'));

      bloc.add(
        const UpdateAvatarSelectionEvent(
          studentId: 's1',
          avatarId: 'owl',
          unlockedAvatarIds: ['owl'],
          coins: 5,
        ),
      );
      await _settle();

      expect(bloc.state.avatarUpdateStatus, SectionStatus.error);
      expect(bloc.state.avatarUpdateError, 'رصيد غير كافٍ');
      expect(bloc.state.profile, _profile);
    });
  });
}
