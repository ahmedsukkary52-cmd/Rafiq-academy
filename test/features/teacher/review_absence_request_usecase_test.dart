import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_pending_absence_requests_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/review_absence_request_usecase.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';

HalaqaEntity _halaqa(String id) => HalaqaEntity(
  id: id,
  name: id,
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: const ['s1'],
  schedule: const [],
  meetingLink: '',
  status: 'active',
);

class _FakeTeacherRepository implements TeacherRepository {
  final List<HalaqaEntity> halaqat;
  final List<AbsenceRequestEntity> pending;
  int reviewCalls = 0;
  int saveAttendanceCalls = 0;
  AbsenceRequestStatus? lastDecision;
  String? lastReviewedRequestId;
  String? lastReviewedBy;

  _FakeTeacherRepository({this.halaqat = const [], this.pending = const []});

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(
    String teacherId,
  ) async => Right(halaqat);

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getPendingAbsenceRequests({
    required String halaqaId,
    required DateTime date,
  }) async => Right(pending);

  @override
  Future<Either<Failure, Unit>> reviewAbsenceRequest({
    required String requestId,
    required String expectedHalaqaId,
    required String teacherId,
    required AbsenceRequestStatus decision,
  }) async {
    reviewCalls++;
    lastReviewedRequestId = requestId;
    lastReviewedBy = teacherId;
    lastDecision = decision;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, AcademyEventPublication>> saveDayAttendance(
    List<AttendanceRecordEntity> r,
  ) async {
    saveAttendanceCalls++;
    return const Right(AcademyEventPublication.none());
  }

  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String h,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> recordAttendance(AttendanceRecordEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) => throw UnimplementedError();
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
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId) => throw UnimplementedError();
  @override
  Future<Either<Failure, AcademyEventPublication>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) => throw UnimplementedError();
}

void main() {
  group('GetPendingAbsenceRequestsUseCase (W7 Slice 2)', () {
    test('returns pending when teacher owns halaqa', () async {
      final pending = [
        AbsenceRequestEntity(
          id: 'h1_s1_20240603',
          studentId: 's1',
          halaqaId: 'h1',
          requestedBy: 'p1',
          date: DateTime(2024, 6, 3),
          reason: 'سفر',
          status: AbsenceRequestStatus.pending,
        ),
      ];
      final repo = _FakeTeacherRepository(
        halaqat: [_halaqa('h1')],
        pending: pending,
      );
      final useCase = GetPendingAbsenceRequestsUseCase(repo);

      final result = await useCase(
        PendingAbsenceRequestsParams(
          teacherId: 't1',
          halaqaId: 'h1',
          date: DateTime(2024, 6, 3, 15),
        ),
      );

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => const []), pending);
    });

    test('rejects unauthorized halaqa', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('other')]);
      final useCase = GetPendingAbsenceRequestsUseCase(repo);

      final result = await useCase(
        PendingAbsenceRequestsParams(
          teacherId: 't1',
          halaqaId: 'h1',
          date: DateTime(2024, 6, 3),
        ),
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('ReviewAbsenceRequestUseCase (W7 Rule 1)', () {
    test('approves request for owned halaqa without attendance I/O', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('h1')]);
      final useCase = ReviewAbsenceRequestUseCase(repo);

      final result = await useCase(
        const ReviewAbsenceRequestParams(
          requestId: 'req1',
          halaqaId: 'h1',
          teacherId: 't1',
          decision: AbsenceRequestStatus.approved,
        ),
      );

      expect(result.isRight(), isTrue);
      expect(repo.reviewCalls, 1);
      expect(repo.saveAttendanceCalls, 0);
      expect(repo.lastDecision, AbsenceRequestStatus.approved);
      expect(repo.lastReviewedBy, 't1');
    });

    test('rejects decision for unowned halaqa', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('other')]);
      final useCase = ReviewAbsenceRequestUseCase(repo);

      final result = await useCase(
        const ReviewAbsenceRequestParams(
          requestId: 'req1',
          halaqaId: 'h1',
          teacherId: 't1',
          decision: AbsenceRequestStatus.rejected,
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(repo.reviewCalls, 0);
      expect(repo.saveAttendanceCalls, 0);
    });

    test('refuses pending as a decision', () async {
      final repo = _FakeTeacherRepository(halaqat: [_halaqa('h1')]);
      final useCase = ReviewAbsenceRequestUseCase(repo);

      final result = await useCase(
        const ReviewAbsenceRequestParams(
          requestId: 'req1',
          halaqaId: 'h1',
          teacherId: 't1',
          decision: AbsenceRequestStatus.pending,
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(repo.reviewCalls, 0);
    });
  });
}
