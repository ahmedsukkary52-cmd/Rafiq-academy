import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
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
    meetingLink: '',
    status: 'active',
  );
}

class _FakeTeacherRepository implements TeacherRepository {
  final List<AttendanceRecordEntity> attendance;
  final List<RecitationRecordEntity> recitations;
  final DateTime? latestDue;
  final Failure? failAttendance;
  final void Function()? onHomework;

  _FakeTeacherRepository({
    this.attendance = const [],
    this.recitations = const [],
    this.latestDue,
    this.failAttendance,
    this.onHomework,
  });

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
  getHalaqaRecitationRecords(String halaqaId) async => Right(recitations);

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
  });
}
