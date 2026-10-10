import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/upsert_teacher_evaluation_usecase.dart';
import 'package:rafiq_academy/shared/domain/evaluation_policy.dart';
import 'package:rafiq_academy/shared/domain/evaluation_service.dart';

const _session = 'h1_20260927';

const _ownedHalaqa = HalaqaEntity(
  id: 'h1',
  name: 'h1',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: ['s1'],
  schedule: [],
  meetingLink: '',
  status: 'active',
);

class _FakeTeacherRepository implements TeacherRepository {
  final Either<Failure, List<AttendanceRecordEntity>> attendance;
  RecitationRecordEntity? upserted;
  bool ownsHalaqa = true;

  _FakeTeacherRepository(this.attendance);

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(
    String teacherId,
  ) async => ownsHalaqa ? const Right([_ownedHalaqa]) : const Right([]);

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async => attendance;

  @override
  Future<Either<Failure, Unit>> upsertTeacherEvaluation({
    required RecitationRecordEntity record,
    required List<String> retireDocumentIds,
  }) async {
    upserted = record;
    return const Right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AttendanceRecordEntity _mark(
  AttendanceStatus status, {
  String studentId = 's1',
  String sessionId = _session,
}) => AttendanceRecordEntity(
  id: '${sessionId}_$studentId',
  studentId: studentId,
  studentName: studentId,
  halaqaId: 'h1',
  date: DateTime(2026, 9, 27),
  status: status,
  recordedBy: 't1',
  sessionId: sessionId,
);

UpsertTeacherEvaluationParams _params() => UpsertTeacherEvaluationParams(
  identity: const EvaluationIdentity(
    sessionId: _session,
    halaqaId: 'h1',
    studentId: 's1',
    type: RecitationType.memorization,
  ),
  sessionDate: DateTime(2026, 9, 27),
  teacherId: 't1',
  studentName: 's1',
  grade: RecitationGrade.excellent,
  behaviorGrade: RecitationGrade.good,
  existingRecords: const [],
);

Future<(Either<Failure, Unit>, _FakeTeacherRepository)> _run(
  Either<Failure, List<AttendanceRecordEntity>> attendance,
) async {
  final repo = _FakeTeacherRepository(attendance);
  final result = await UpsertTeacherEvaluationUseCase(
    repo,
    const EvaluationService(),
  )(_params());
  return (result, repo);
}

void main() {
  group('UpsertTeacherEvaluationUseCase D7 attendance gate', () {
    for (final status in [AttendanceStatus.present, AttendanceStatus.late]) {
      test('$status on the same session is evaluated', () async {
        final (result, repo) = await _run(Right([_mark(status)]));

        expect(result.isRight(), isTrue);
        expect(repo.upserted?.id, '${_session}_s1_memorization');
        expect(repo.upserted?.sessionId, _session);
      });
    }

    for (final status in [AttendanceStatus.absent, AttendanceStatus.excused]) {
      test('$status student is not evaluated', () async {
        final (result, repo) = await _run(Right([_mark(status)]));

        expect(
          result,
          const Left<Failure, Unit>(
            ValidationFailure(
              UpsertTeacherEvaluationUseCase.notAttendedMessage,
            ),
          ),
        );
        expect(repo.upserted, isNull);
      });
    }

    test('unmarked student is not evaluated', () async {
      final (result, repo) = await _run(
        Right([_mark(AttendanceStatus.present, studentId: 's2')]),
      );

      expect(result.isLeft(), isTrue);
      expect(repo.upserted, isNull);
    });

    test('presence on a different session does not count', () async {
      final (result, repo) = await _run(
        Right([_mark(AttendanceStatus.present, sessionId: 'h1_20260926')]),
      );

      expect(result.isLeft(), isTrue);
      expect(repo.upserted, isNull);
    });

    test('present student in a halaqa the teacher does not own is not evaluated',
        () async {
      final repo = _FakeTeacherRepository(
        Right([_mark(AttendanceStatus.present)]),
      )..ownsHalaqa = false;
      final result = await UpsertTeacherEvaluationUseCase(
        repo,
        const EvaluationService(),
      )(_params());

      expect(result.isLeft(), isTrue);
      expect(repo.upserted, isNull);
    });

    test('attendance read failure is surfaced without writing', () async {
      const failure = ServerFailure('offline');
      final (result, repo) = await _run(const Left(failure));

      expect(result, const Left<Failure, Unit>(failure));
      expect(repo.upserted, isNull);
    });
  });
}
