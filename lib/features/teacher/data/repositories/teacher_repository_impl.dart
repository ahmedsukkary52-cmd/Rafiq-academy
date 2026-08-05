import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../../../../shared/domain/academy_event_sink.dart';
import '../../../student/data/models/recitation_record_model.dart';
import '../../../parent/domain/entities/parent_entities.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../domain/entities/attendance_record_entity.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../data_sources/teacher_remote_datasource.dart';
import '../models/attendance_record_model.dart';

@LazySingleton(as: TeacherRepository)
class TeacherRepositoryImpl implements TeacherRepository {
  final TeacherRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  /// Delivery port. The teacher feature never learns which handlers exist.
  final AcademyEventSink eventSink;

  const TeacherRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
    required this.eventSink,
  });

  /// SSOT is already committed; sink failure never rolls it back.
  ///
  /// Returns channel-neutral publication observability (published? which
  /// handlers succeeded/failed?) — never notification-specific metrics.
  Future<AcademyEventPublication> _publishAfterCommit(
    List<AcademyEvent> events,
  ) async {
    if (events.isEmpty) return const AcademyEventPublication.none();
    try {
      final report = await eventSink.publish(events);
      return AcademyEventPublication(
        eventCount: events.length,
        eventsPublished: report.anySucceeded,
        handlerReports: report.handlers,
      );
    } catch (e) {
      return AcademyEventPublication(
        eventCount: events.length,
        eventsPublished: false,
        handlerReports: [
          AcademyEventHandlerReport(
            handlerName: 'publish',
            succeeded: false,
            error: e,
          ),
        ],
      );
    }
  }

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(
    String teacherId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getTeacherHalaqat(teacherId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getHalaqaStudents(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> recordAttendance(
    AttendanceRecordEntity record,
  ) async {
    final result = await saveDayAttendance([record]);
    return result.map((_) => unit);
  }

  @override
  Future<Either<Failure, AcademyEventPublication>> saveDayAttendance(
    List<AttendanceRecordEntity> records,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());

    final List<AcademyEvent> events;
    try {
      events = await remoteDatasource.saveDayAttendance(
        records
            .map(
              (record) => AttendanceRecordModel(
                id: record.id,
                studentId: record.studentId,
                studentName: record.studentName,
                halaqaId: record.halaqaId,
                date: record.date,
                status: record.status,
                recordedBy: record.recordedBy,
              ),
            )
            .toList(),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }

    return Right(await _publishAfterCommit(events));
  }

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getHalaqaAttendanceForDate(
          halaqaId: halaqaId,
          date: date,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> addRecitationRecord(
    RecitationRecordEntity record,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.addRecitationRecord(
        RecitationRecordModel(
          id: record.id,
          studentId: record.studentId,
          teacherId: record.teacherId,
          halaqaId: record.halaqaId,
          date: record.date,
          type: record.type,
          versesRange: record.versesRange,
          sessionId: record.sessionId,
          grade: record.grade,
          notes: record.notes,
          studentName: record.studentName,
          behaviorGrade: record.behaviorGrade,
        ),
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> upsertTeacherEvaluation({
    required RecitationRecordEntity record,
    required List<String> retireDocumentIds,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.upsertTeacherEvaluation(
        record: RecitationRecordModel(
          id: record.id,
          studentId: record.studentId,
          teacherId: record.teacherId,
          halaqaId: record.halaqaId,
          date: record.date,
          type: record.type,
          versesRange: record.versesRange,
          sessionId: record.sessionId,
          grade: record.grade,
          notes: record.notes,
          studentName: record.studentName,
          behaviorGrade: record.behaviorGrade,
          reviewStatus: record.reviewStatus,
        ),
        retireDocumentIds: retireDocumentIds,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, AcademyEventPublication>> updateRecitationReview(
    UpdateRecitationReviewParams params,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());

    final List<AcademyEvent> events;
    try {
      events = await remoteDatasource.updateRecitationReview(
        recordId: params.recordId,
        grade: params.grade,
        behaviorGrade: params.behaviorGrade,
        notes: params.notes,
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }

    return Right(await _publishAfterCommit(events));
  }

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getHalaqaRecitationRecords(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, AcademyEventPublication>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());

    final List<AcademyEvent> events;
    try {
      events = await remoteDatasource.sendAssignment(
        halaqaId: halaqaId,
        newMemorizationRange: newMemorizationRange,
        reviewRange: reviewRange,
        dueDate: dueDate,
        teacherId: teacherId,
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }

    return Right(await _publishAfterCommit(events));
  }

  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.getLatestAssignmentDueDate(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getPendingAbsenceRequests({
    required String halaqaId,
    required DateTime date,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getPendingAbsenceRequests(
          halaqaId: halaqaId,
          date: date,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> reviewAbsenceRequest({
    required String requestId,
    required String expectedHalaqaId,
    required String teacherId,
    required AbsenceRequestStatus decision,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.reviewAbsenceRequest(
        requestId: requestId,
        expectedHalaqaId: expectedHalaqaId,
        teacherId: teacherId,
        decision: decision,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
