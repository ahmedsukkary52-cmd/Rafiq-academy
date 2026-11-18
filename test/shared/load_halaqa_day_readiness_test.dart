import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_query_mode.dart';
import 'package:rafiq_academy/shared/domain/attendance_record_entity.dart';
import 'package:rafiq_academy/shared/domain/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';
import 'package:rafiq_academy/shared/domain/halaqa_day_readiness.dart';
import 'package:rafiq_academy/shared/domain/load_halaqa_day_readiness.dart';

final _monday = DateTime(2024, 6, 3, 9, 0);
final _mondayDue = DateTime(2024, 6, 3, 23, 59, 59);

HalaqaEntity _halaqa({List<String> studentIds = const ['s1']}) {
  return HalaqaEntity(
    id: 'h1',
    name: 'حلقة',
    teacherId: 't1',
    supervisorId: 'sup1',
    studentIds: studentIds,
    schedule: const [
      HalaqaScheduleEntity(day: 'monday', startTime: '09:00', endTime: '10:00'),
    ],
    status: 'active',
  );
}

class _FakeTeacherRepository implements TeacherRepository {
  final List<AttendanceRecordEntity> attendance;
  final List<RecitationRecordEntity> recitations;
  final DateTime? latestDue;
  final Failure? failAttendance;
  final void Function()? onHomework;
  final List<int?> recitationMaxRecordsCalls;
  final List<RecitationRecordsQueryMode> recitationModeCalls;

  _FakeTeacherRepository({
    this.attendance = const [],
    this.recitations = const [],
    this.latestDue,
    this.failAttendance,
    this.onHomework,
    List<int?>? recitationMaxRecordsCalls,
    List<RecitationRecordsQueryMode>? recitationModeCalls,
  }) : recitationMaxRecordsCalls = recitationMaxRecordsCalls ?? <int?>[],
       recitationModeCalls =
           recitationModeCalls ?? <RecitationRecordsQueryMode>[];

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async {
    if (failAttendance != null) return Left(failAttendance!);
    return Right(attendance);
  }

  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) async {
    onHomework?.call();
    return Right(latestDue);
  }

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId, {int? maxRecords, RecitationRecordsQueryMode mode = RecitationRecordsQueryMode.fullHistory}) async {
    recitationMaxRecordsCalls.add(maxRecords);
    recitationModeCalls.add(mode);
    if (maxRecords == null) return Right(recitations);
    final sorted = [...recitations]
      ..sort((a, b) => b.date.compareTo(a.date));
    return Right(sorted.take(maxRecords).toList());
  }

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(String t) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String h,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> recordAttendance(AttendanceRecordEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, AcademyEventPublication>> saveDayAttendance(
    List<AttendanceRecordEntity> r,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> addRecitationRecord(RecitationRecordEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> upsertTeacherEvaluation({
    required RecitationRecordEntity record,
    required List<String> retireDocumentIds,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, AcademyEventPublication>> updateRecitationReview(
    UpdateRecitationReviewParams p,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, AcademyEventPublication>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getPendingAbsenceRequests({
    required String halaqaId,
    required DateTime date,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> reviewAbsenceRequest({
    required String requestId,
    required String expectedHalaqaId,
    required String teacherId,
    required AbsenceRequestStatus decision,
  }) => throw UnimplementedError();
}

void main() {
  group('loadHalaqaDayReadiness (H2 / A-H14)', () {
    test('skips homework read when roster empty', () async {
      var homeworkReads = 0;
      final result = await loadHalaqaDayReadiness(
        teacherRepository: _FakeTeacherRepository(
          onHomework: () => homeworkReads++,
        ),
        halaqa: _halaqa(studentIds: const []),
        now: _monday,
      );

      expect(result.isRight(), isTrue);
      expect(homeworkReads, 0);
      expect(
        result.getOrElse((_) => HalaqaDayReadiness.complete).isComplete,
        isTrue,
      );
    });

    test('projects homework pending when latest due is not today', () async {
      final result = await loadHalaqaDayReadiness(
        teacherRepository: _FakeTeacherRepository(
          attendance: [
            AttendanceRecordEntity(
              id: 'a1',
              studentId: 's1',
              studentName: 's1',
              halaqaId: 'h1',
              date: _monday,
              status: AttendanceStatus.present,
              recordedBy: 't1',
              sessionId: 'h1_20240603',
            ),
          ],
          latestDue: DateTime(2024, 6, 2, 23, 59, 59),
        ),
        halaqa: _halaqa(),
        now: _monday,
      );

      final readiness = result.getOrElse((_) => HalaqaDayReadiness.complete);
      expect(
        readiness.gaps.any((g) => g.kind == HalaqaDayGapKind.homeworkPending),
        isTrue,
      );
    });

    test('complete when attendance + today homework + no pending reviews', () async {
      final result = await loadHalaqaDayReadiness(
        teacherRepository: _FakeTeacherRepository(
          attendance: [
            AttendanceRecordEntity(
              id: 'a1',
              studentId: 's1',
              studentName: 's1',
              halaqaId: 'h1',
              date: _monday,
              status: AttendanceStatus.present,
              recordedBy: 't1',
              sessionId: 'h1_20240603',
            ),
          ],
          latestDue: _mondayDue,
        ),
        halaqa: _halaqa(),
        now: _monday,
      );

      expect(
        result.getOrElse((_) => HalaqaDayReadiness.complete).isComplete,
        isTrue,
      );
    });

    test('propagates attendance failure', () async {
      final result = await loadHalaqaDayReadiness(
        teacherRepository: _FakeTeacherRepository(
          failAttendance: const ServerFailure('boom'),
        ),
        halaqa: _halaqa(),
        now: _monday,
      );
      expect(result.isLeft(), isTrue);
    });

    test('pending reviews beyond a 100-newest window still count', () async {
      final calls = <int?>[];
      final recitations = <RecitationRecordEntity>[
        for (var i = 0; i < 130; i++)
          RecitationRecordEntity(
            id: 'r$i',
            studentId: 's1',
            studentName: 'n',
            teacherId: 't1',
            halaqaId: 'h1',
            date: DateTime(2024, 1, 1).add(Duration(days: i)),
            type: RecitationType.memorization,
            versesRange: '',
            // Oldest 15 are pending — outside any newest-100 window.
            reviewStatus: i < 15 ? 'pending' : 'reviewed',
          ),
      ];
      final repo = _FakeTeacherRepository(
        attendance: [
          AttendanceRecordEntity(
            id: 'a1',
            studentId: 's1',
            studentName: 's1',
            halaqaId: 'h1',
            date: _monday,
            status: AttendanceStatus.present,
            recordedBy: 't1',
            sessionId: 'h1_20240603',
          ),
        ],
        latestDue: _mondayDue,
        recitations: recitations,
        recitationMaxRecordsCalls: calls,
      );

      final facts = await loadHalaqaDayFacts(
        teacherRepository: repo,
        halaqa: _halaqa(),
        now: _monday,
      );
      final value = facts.getOrElse((_) => throw StateError('expected Right'));

      expect(calls, [null], reason: 'readiness must request full history');
      expect(
        repo.recitationModeCalls,
        [RecitationRecordsQueryMode.fullHistory],
      );
      expect(
        value.readiness.gaps
            .where((g) => g.kind == HalaqaDayGapKind.reviewsPending)
            .single
            .quantity,
        15,
      );

      // Contrast: a silent newest-100 cap would drop all 15 oldest pending.
      final newest100 = [...recitations]
        ..sort((a, b) => b.date.compareTo(a.date));
      expect(
        newest100.take(100).where((r) => r.isPendingReview),
        isEmpty,
      );
    });
  });
}
