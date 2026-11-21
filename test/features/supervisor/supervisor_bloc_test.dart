import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/achievement_issue_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/read_models/supervisor_day_board.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/admit_student_to_halaqa_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_absence_requests_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervised_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervisor_day_board_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/issue_achievement_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/payment_review_usecases.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/register_new_student_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/submit_supervisor_report_usecase.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/transfer_student_between_halaqat_usecase.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_bloc.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_event.dart';
import 'package:rafiq_academy/features/supervisor/presentation/bloc/supervisor_state.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';

typedef _E<T> = Either<Failure, T>;

class _Script<P, R> {
  _Script(this.respond);

  R Function(P params) respond;
  final params = <P>[];

  Future<R> run(P p) async {
    params.add(p);
    return respond(p);
  }
}

const _halaqa = HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: [],
  schedule: [],
  status: 'active',
);

const _achievement = AchievementIssueEntity(
  achievementId: 'achSubmission01',
  studentId: 's1',
  type: 'excellence',
  title: 'تميز',
  issuedBy: 'sup1',
  halaqaId: 'h1',
);

class _Halaqat extends Fake implements GetSupervisedHalaqatUseCase {
  final s = _Script<SupervisorIdParams, _E<List<HalaqaEntity>>>(
    (_) => const Right([_halaqa]),
  );
  @override
  Future<_E<List<HalaqaEntity>>> call(SupervisorIdParams p) => s.run(p);
}

class _Board extends Fake implements GetSupervisorDayBoardUseCase {
  final s = _Script<SupervisorDayBoardParams, _E<SupervisorDayBoard>>(
    (_) => const Right(SupervisorDayBoard.empty),
  );
  @override
  Future<_E<SupervisorDayBoard>> call(SupervisorDayBoardParams p) => s.run(p);
}

class _Absence extends Fake implements GetSupervisedAbsenceRequestsUseCase {
  final s =
      _Script<SupervisedAbsenceRequestsParams, _E<List<AbsenceRequestEntity>>>(
        (_) => const Right([]),
      );
  @override
  Future<_E<List<AbsenceRequestEntity>>> call(
    SupervisedAbsenceRequestsParams p,
  ) => s.run(p);
}

class _Issue extends Fake implements IssueAchievementUseCase {
  final s = _Script<AchievementIssueEntity, _E<Unit>>((_) => const Right(unit));
  @override
  Future<_E<Unit>> call(AchievementIssueEntity p) => s.run(p);
}

class _Register extends Fake implements RegisterNewStudentUseCase {
  final s = _Script<RegisterStudentParams, _E<Unit>>((_) => const Right(unit));
  @override
  Future<_E<Unit>> call(RegisterStudentParams p) => s.run(p);
}

class _UnusedReport extends Fake implements SubmitSupervisorReportUseCase {}

class _Admit extends Fake implements AdmitStudentToHalaqaUseCase {
  final params = <AdmitStudentParams>[];
  @override
  Future<_E<Unit>> call(AdmitStudentParams p) async {
    params.add(p);
    return const Right(unit);
  }
}

class _UnusedTransfer extends Fake
    implements TransferStudentBetweenHalaqatUseCase {}

class _UnusedPayments extends Fake implements GetSupervisedPaymentsUseCase {}

class _UnusedReview extends Fake implements ReviewPaymentProofUseCase {}

class _Harness {
  final halaqat = _Halaqat();
  final board = _Board();
  final absence = _Absence();
  final issue = _Issue();
  final register = _Register();
  final admit = _Admit();

  late final bloc = SupervisorBloc(
    getSupervisedHalaqat: halaqat,
    getSupervisorDayBoard: board,
    getSupervisedAbsenceRequests: absence,
    issueAchievement: issue,
    submitSupervisorReport: _UnusedReport(),
    admitStudentToHalaqa: admit,
    transferStudentBetweenHalaqat: _UnusedTransfer(),
    getSupervisedPayments: _UnusedPayments(),
    reviewPaymentProof: _UnusedReview(),
    registerNewStudent: register,
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Harness h;

  setUp(() => h = _Harness());
  tearDown(() => h.bloc.close());

  test('initial state is idle', () {
    expect(h.bloc.state, SupervisorState.initial());
  });

  group('dashboard load', () {
    test('halaqat feed the day board, then absence requests load', () async {
      h.bloc.add(const LoadSupervisedHalaqatEvent('sup1'));
      await _settle();

      expect(h.halaqat.s.params.single.supervisorId, 'sup1');
      expect(h.bloc.state.halaqatStatus, SectionStatus.loaded);
      expect(h.board.s.params.single.halaqat, [_halaqa]);
      expect(h.bloc.state.dayBoardStatus, SectionStatus.loaded);
      expect(h.absence.s.params.single.supervisorId, 'sup1');
      expect(h.bloc.state.absenceRequestsStatus, SectionStatus.loaded);
    });

    test('supervisor with no halaqat gets an empty board', () async {
      h.halaqat.s.respond = (_) => const Right([]);
      h.bloc.add(const LoadSupervisedHalaqatEvent('sup1'));
      await _settle();

      expect(h.bloc.state.halaqat, isEmpty);
      expect(h.bloc.state.dayBoard, SupervisorDayBoard.empty);
      expect(h.bloc.state.dayBoardStatus, SectionStatus.loaded);
    });

    test('halaqat failure loads nothing downstream', () async {
      h.halaqat.s.respond = (_) => const Left(NetworkFailure());
      h.bloc.add(const LoadSupervisedHalaqatEvent('sup1'));
      await _settle();

      expect(h.bloc.state.halaqatStatus, SectionStatus.error);
      expect(h.bloc.state.halaqatError, const NetworkFailure().message);
      expect(h.board.s.params, isEmpty);
      expect(h.absence.s.params, isEmpty);
    });

    test('day board failure can be retried', () async {
      h.board.s.respond = (_) => const Left(ServerFailure('تعذر اللوحة'));
      h.bloc.add(const LoadSupervisedHalaqatEvent('sup1'));
      await _settle();
      expect(h.bloc.state.dayBoardStatus, SectionStatus.error);
      expect(h.bloc.state.dayBoardError, 'تعذر اللوحة');

      h.board.s.respond = (_) => const Right(SupervisorDayBoard.empty);
      h.bloc.add(const LoadSupervisorDayBoardEvent());
      await _settle();

      expect(h.halaqat.s.params, hasLength(1));
      expect(h.bloc.state.dayBoardStatus, SectionStatus.loaded);
      expect(h.absence.s.params, hasLength(2));
    });

    test('absence request failure is isolated', () async {
      h.absence.s.respond = (_) => const Left(ServerFailure('x'));
      h.bloc.add(const LoadSupervisedHalaqatEvent('sup1'));
      await _settle();

      expect(h.bloc.state.dayBoardStatus, SectionStatus.loaded);
      expect(h.bloc.state.absenceRequestsStatus, SectionStatus.error);
    });
  });

  group('actions', () {
    test('issue achievement success, then reset', () async {
      h.bloc.add(const IssueAchievementEvent(_achievement));
      await _settle();

      expect(h.issue.s.params.single, _achievement);
      expect(h.bloc.state.issueAchievementStatus, SubmissionStatus.success);

      h.bloc.add(const ResetIssueAchievementEvent());
      await _settle();
      expect(h.bloc.state.issueAchievementStatus, SubmissionStatus.idle);
    });

    test('issue achievement failure is surfaced', () async {
      h.issue.s.respond = (_) => const Left(ServerFailure('غير مسموح'));
      h.bloc.add(const IssueAchievementEvent(_achievement));
      await _settle();

      expect(h.bloc.state.issueAchievementStatus, SubmissionStatus.error);
      expect(h.bloc.state.issueAchievementError, 'غير مسموح');
    });

    test('admit student passes halaqa and student through', () async {
      h.bloc.add(
        const RegisterNewStudentEvent(halaqaId: 'h1', studentId: 's9'),
      );
      await _settle();

      expect(h.register.s.params.single.halaqaId, 'h1');
      expect(h.register.s.params.single.studentId, 's9');
      expect(h.bloc.state.registerStudentStatus, SubmissionStatus.success);
    });

    test('admit refreshes the shared roster before success', () async {
      h.bloc.add(
        const AdmitStudentToHalaqaEvent(
          supervisorId: 'sup1',
          halaqaId: 'h1',
          studentId: 's9',
        ),
      );
      await _settle();

      expect(h.admit.params.single.studentId, 's9');
      expect(h.admit.params.single.halaqaId, 'h1');
      expect(h.halaqat.s.params.single.supervisorId, 'sup1');
      expect(h.bloc.state.admitStudentStatus, SubmissionStatus.success);
      expect(h.bloc.state.admitStudentRosterRefreshFailed, isFalse);
      expect(h.bloc.state.halaqatStatus, SectionStatus.loaded);
    });

    test('admit failure keeps the error until reset', () async {
      h.register.s.respond = (_) => const Left(ServerFailure('الطالب مسجل'));
      h.bloc.add(
        const RegisterNewStudentEvent(halaqaId: 'h1', studentId: 's9'),
      );
      await _settle();
      expect(h.bloc.state.registerStudentStatus, SubmissionStatus.error);
      expect(h.bloc.state.registerStudentError, 'الطالب مسجل');

      h.bloc.add(const ResetRegisterStudentEvent());
      await _settle();
      expect(h.bloc.state.registerStudentStatus, SubmissionStatus.idle);
      expect(h.bloc.state.registerStudentError, isNull);
    });
  });

  test('logout clears state and forgets the supervisor id', () async {
    h.bloc.add(const LoadSupervisedHalaqatEvent('sup1'));
    await _settle();
    h.bloc.add(const ClearSupervisorSessionEvent());
    await _settle();
    expect(h.bloc.state, SupervisorState.initial());

    h.bloc.add(const LoadSupervisorDayBoardEvent());
    await _settle();
    expect(h.absence.s.params, hasLength(1));
  });
}
